{-# LANGUAGE TemplateHaskell, PatternSynonyms #-}
module Main where

import Control.Applicative
import Control.Lens
import Control.Monad hiding (forM_)
-- import Control.Monad.Random
import Control.Monad.State
import Engine.SDL.Basic
import Engine.SDL.Video
import Engine.Var
import Foreign
import Foreign.C
import System.Exit
import Graphics.Rendering.OpenGL as GL hiding (doubleBuffer)
import Graphics.Rendering.OpenGL.Raw as GL
import Graphics.UI.SDL.Enum.Pattern as SDL
import Graphics.UI.SDL.Event as SDL
import Graphics.UI.SDL.Types as SDL
import Graphics.UI.SDL.Video as SDL
import Prelude hiding (init)

data Config = Config { _configFullScreen :: !Bool, _configWindow :: Window }

makeClassy ''Config

main :: IO ()
main = withCString "engine" $ \windowName -> do
  ver <- version
  putStrLn $ "SDL2 " ++ show ver
  init InitFlagEverything
  contextMajorVersion &= 4
  contextMinorVersion &= 1
  contextProfileMask  &= GLProfileCore
  redSize   &= 5
  greenSize &= 5
  blueSize  &= 5
  depthSize &= 16
  doubleBuffer &= True
  -- shareWithCurrentContext &= True
  window <- createWindow windowName WindowPosUndefined WindowPosUndefined 1024 768 (WindowFlagOpenGL .|. WindowFlagShown .|. WindowFlagResizable .|. WindowFlagAllowHighDPI)
  -- physicsContext   <- glCreateContext window
  -- renderingContext <- glCreateContext window
  _ <- glCreateContext window
  glEnable gl_FRAMEBUFFER_SRGB
  () <$ execStateT (forever $ poll >> render) (Config False window) --  renderingContext)

render :: (MonadIO m, MonadState s m, HasConfig s) => m ()
render = do
  w <- use configWindow
  liftIO $ do
    -- r <- (*0.01) <$> randomIO
    clearColor $= Color4 0 0 0 1
    clear [ColorBuffer, StencilBuffer, DepthBuffer]
    glSwapWindow w

shutdown :: MonadIO m => m ()
shutdown = liftIO $ quit >> exitSuccess

poll :: HasConfig s => StateT s IO ()
poll = StateT $ \s -> alloca $ \ep -> runStateT (go ep) s where
  go ep = liftIO (pollEvent ep) >>= \ r -> when (r /= 0) $ do
    e <- liftIO (peek ep)
    handleEvent e
    go ep

handleEvent :: HasConfig s => SDL.Event -> StateT s IO ()
handleEvent QuitEvent{} = shutdown
-- escape
handleEvent KeyboardEvent{keyboardEventKeysym=Keysym{keysymKeycode = KeycodeEscape}} = shutdown
-- alt-enter, full screen toggle
handleEvent KeyboardEvent{eventType = EventTypeKeyDown, keyboardEventKeysym=Keysym{keysymKeycode = KeycodeReturn, keysymMod = m }} 
  | m .&. (KeymodRAlt .|. KeymodLAlt .|. KeymodRGUI .|. KeymodLGUI) /= 0 = do
  fs <- configFullScreen <%= not
  w  <- use configWindow
  _ <- liftIO $ setWindowFullscreen w $ if fs then WindowFlagFullscreenDesktop else 0
  return ()
handleEvent e = liftIO $ print e