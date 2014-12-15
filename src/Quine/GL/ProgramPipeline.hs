{-# LANGUAGE DeriveDataTypeable #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE DeriveGeneric #-}
--------------------------------------------------------------------
-- |
-- Copyright :  (c) 2014 Edward Kmett and Jan-Philip Loos
-- License   :  BSD2
-- Maintainer:  Edward Kmett <ekmett@gmail.com>
-- Stability :  experimental
-- Portability: non-portable
--
-- Separable 'Programs's can be combined to a 'ProgramPipeline'
-- Requires: 4.1+ or GL_ARB_separate_shader_objects
--------------------------------------------------------------------
module Quine.GL.ProgramPipeline
  ( ProgramPipeline
  , PipelineStage
  , boundProgramPipeline
  , useProgramStages
  -- * Properties
  , programPipelineParameter1
  , programPipelineInfoLog
  , validateProgramPipeline
  , validateStatus
  ) where

import Control.Applicative
import Control.Monad
import Control.Monad.IO.Class
import Data.Coerce
import Data.Data
import Data.Default
import Foreign.Marshal.Alloc
import Foreign.Marshal.Array
import Foreign.Ptr
import Foreign.Storable
import GHC.Generics
import Graphics.GL.Core45
import Graphics.GL.Types
import qualified Data.ByteString as Strict
import qualified Data.ByteString.Internal as Strict
import Quine.GL.Object
import Quine.GL.Program hiding (validateStatus)
import Quine.StateVar

-- | A Pipeline object captures shader stages
newtype ProgramPipeline = ProgramPipeline GLuint deriving (Eq,Ord,Show,Read,Typeable,Data,Generic)

type PipelineStage = GLbitfield

instance Object ProgramPipeline where
  object = coerce
  isa i = (GL_FALSE /=) `liftM` glIsProgramPipeline (coerce i)
  deletes xs = liftIO $ allocaArray n $ \p -> do
    pokeArray p (coerce xs)
    glDeleteProgramPipelines (fromIntegral n) p
    where n = length xs

instance Gen ProgramPipeline where
  gens n = liftIO $ allocaArray n $ \p -> do
    glGenProgramPipelines (fromIntegral n) p
    map ProgramPipeline <$> peekArray n p

instance Default ProgramPipeline where
  def = ProgramPipeline 0

-- * Properties

programPipelineParameter1 :: ProgramPipeline -> GLenum -> GettableStateVar GLint
programPipelineParameter1 p parm = alloca $ liftM2 (>>) (glGetProgramPipelineiv (coerce p) parm) peek

programPipelineInfoLog :: MonadIO m => ProgramPipeline -> m Strict.ByteString
programPipelineInfoLog p = liftIO $ do
  l <- fromIntegral <$> get (programPipelineParameter1 p GL_INFO_LOG_LENGTH)
  if l <= 1
    then return Strict.empty
    else liftIO $ alloca $ \pl -> do
      Strict.createUptoN l $ \ps -> do
        glGetProgramPipelineInfoLog (object p) (fromIntegral l) pl (castPtr ps)
        return $ l-1

-- * Validation

-- | @'validateProgramPipeline' pipeline@ instructs the implementation to validate the shader executables contained in @pipeline@ against the current GL state. The implementation may use this as an opportunity to perform any internal shader modifications that may be required to ensure correct operation of the installed shaders given the current GL state.
--
validateProgramPipeline :: MonadIO m => ProgramPipeline -> m ()
validateProgramPipeline = glValidateProgramPipeline . coerce

-- | @'validateStatus' pipeline@ returns 'True' if the last validation operation on @pipeline@ was successful, and 'False' otherwise.
--
-- If 'True', @pipeline@ is guaranteed to execute given the current state. Otherwise, @pipeline@ is guaranteed to not execute.
validateStatus :: MonadIO m => ProgramPipeline -> m Bool
validateStatus p = (GL_FALSE /=) `liftM` get (programPipelineParameter1 p GL_VALIDATE_STATUS)

-- * Binding

boundProgramPipeline :: StateVar ProgramPipeline
boundProgramPipeline = StateVar g s where
  g = fmap (ProgramPipeline . fromIntegral) $ alloca $ liftM2 (>>) (glGetIntegerv GL_PROGRAM_PIPELINE_BINDING) peek
  s = glBindProgramPipeline . coerce

-- * Stages

useProgramStages :: MonadIO m => ProgramPipeline -> PipelineStage -> Program -> m ()
useProgramStages pipe stage prog = glUseProgramStages (coerce pipe) stage (coerce prog)
