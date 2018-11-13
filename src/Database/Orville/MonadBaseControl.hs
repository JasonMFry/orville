{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE RankNTypes #-}
{-# LANGUAGE UndecidableInstances #-}
{-# LANGUAGE TypeFamilies #-}

{-|
   'Database.Orville.MonadBaseControl' provides functions and instances for
   using 'MonadOrville' and 'OrvilleT' for situations where you need to use
   'MonadBaseControl'. If you do not know if you need 'MonadBaseControl', then
   you probably don't need to use this module. If you are thinking about
   using 'MonadBaseControl' instead of 'MonadUnliftIO', we recommend
   reading Michael Snoyman's excellent "A Tale of Two Brackets"
   (https://www.fpcomplete.com/blog/2017/06/tale-of-two-brackets) if you
   have not already done so.

   If you're still here after reading above, this module provides
   the functions you need to implement 'MonadOrvilleControl' for your
   Monad stack using its 'MonadBaseControl' instance. The most common way
   to do this is simply to add the following 'MonadOrvilleControl' instance:

   @
    instance MonadOrvilleControl MyMonad where
      liftWithConnection = liftWithConnectionViaBaseControl
      liftFinally = liftFinallyViaBaseControl
   @

   This module also provides a 'MonadOrvilleControl' for 'StateT' as well as
   'MonadBaseControl' and 'MonadTransControl' instances for 'OrvilleT'.
 |-}
module Database.Orville.MonadBaseControl
  ( liftWithConnectionViaBaseControl
  , liftFinallyViaBaseControl
  ) where

import Control.Monad.Reader (ReaderT)
import Control.Monad.State (StateT(StateT, runStateT))
import Control.Monad.Trans (lift)
import qualified Control.Monad.Trans.Control as MTC

import qualified Database.Orville as O
import qualified Database.Orville.Internal.Monad as Internal

{-|
   liftWithConnectionViaBaseControl can be use as the implementation of
   'liftWithConnection' for 'MonadOrvilleControl' when the 'Monad'
   implements 'MonadBaseControl'.
 |-}
liftWithConnectionViaBaseControl ::
     MTC.MonadBaseControl IO m
  => (forall b. (conn -> IO b) -> IO b)
  -> (conn -> m a)
  -> m a
liftWithConnectionViaBaseControl ioWithConn action =
  MTC.control $ \runInIO -> ioWithConn (runInIO . action)

{-|
   liftFinallyViaBaseControl can be use as the implementation of
   'liftFinally for 'MonadOrvilleControl' when the 'Monad'
   implements 'MonadBaseControl'.
 |-}
liftFinallyViaBaseControl ::
     MTC.MonadBaseControl IO m
  => (forall c d. IO c -> IO d -> IO c)
  -> m a
  -> m b
  -> m a
liftFinallyViaBaseControl ioFinally action cleanup =
  MTC.control $ \runInIO -> ioFinally (runInIO action) (runInIO cleanup)

{-|
   Because lifting control operations into 'StateT' is fraught with peril, a
   'MonadOrvilleControl' instance for 'StateT' is provided here and implemented
   via 'MonadBaseControl' rather than together with the 'MonadOrvilleControl'
   definition. We do not recommend using stateful Monad transformer layers in
   Monad stacks based on IO. For anyone that must, this is the canonical
   instance for 'StateT'
  |-}
instance MTC.MonadBaseControl IO m => O.MonadOrvilleControl (StateT a m) where
  liftWithConnection = liftWithConnectionViaBaseControl
  liftFinally = liftFinallyViaBaseControl

{-|
   Because 'MonadOrvilleControl' is a superclass of 'MonadOrville', the
   'MonadOrville' instace of 'StateT' is provided here instead with the
   definition of 'MonadOrville'. See the commentary on the other instance
   for an admonition to not use it :)
  |-}
instance (MTC.MonadBaseControl IO m, O.MonadOrville conn m) =>
         O.MonadOrville conn (StateT a m) where
  getOrvilleEnv = lift O.getOrvilleEnv
  localOrvilleEnv modEnv action =
    StateT $ \val -> O.localOrvilleEnv modEnv (runStateT action val)

{-|
   Because we recommend using 'MonadUnliftIO' rather than 'MonadTransControl',
   we do not provide 'MonadTransControl' instance for 'OrvilleT' by default
   along with the definition. If you do need to use 'MonadTransControl',
   however, this is the canonical instance for 'OrvilleT'.
  |-}
instance MTC.MonadTransControl (O.OrvilleT conn) where
  type StT (O.OrvilleT conn) a = MTC.StT (ReaderT (O.OrvilleEnv conn)) a
  liftWith = MTC.defaultLiftWith Internal.OrvilleT Internal.unOrvilleT
  restoreT = MTC.defaultRestoreT Internal.OrvilleT

{-|
   Because we recommend using 'MonadUnliftIO' rather than 'MonadBaseControl',
   we do not provide 'MonadBaseControl' instance for 'OrvilleT' by default
   along with the definition. If you do need to use 'MonadBaseControl',
   however, this is the canonical instance for 'OrvilleT'.
  |-}
instance MTC.MonadBaseControl b m =>
         MTC.MonadBaseControl b (O.OrvilleT conn m) where
  type StM (O.OrvilleT conn m) a = MTC.ComposeSt (O.OrvilleT conn) m a
  liftBaseWith = MTC.defaultLiftBaseWith
  restoreM = MTC.defaultRestoreM