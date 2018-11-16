module UnliftIOTest where

import Control.Monad.Catch (MonadThrow)
import qualified Control.Monad.IO.Unlift as UL
import qualified Database.HDBC.PostgreSQL as Postgres
import qualified Database.Orville as O
import qualified Database.Orville.MonadUnliftIO as OULIO

import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit (testCase)

import qualified TestDB as TestDB

{-|
   'ThirdPartyMonad' is a stand in for a Monad (or Monad Transformer) that an
   Orville user might by using from another library that doesn't know anything
   about the Orville Monad stack. We would like to make using such third
   parties painless as possible.
  -}
newtype ThirdPartyMonad a = ThirdPartyMonad
  { runThirdPartyMonad :: IO a
  } deriving ( Functor
             , Applicative
             , Monad
             , UL.MonadIO
             , UL.MonadUnliftIO
             , MonadThrow
             )

{-|
   'EndUserMonad' is a stand in for the Monad stack that an Orville user might
   build using a third party monad from another library. We would like to make
   it easy to build the typeclass instances that Orville requires as easy as
   possible for new users.
  -}
newtype EndUserMonad a = EndUserMonad
  { runEndUserMonad :: O.OrvilleT Postgres.Connection ThirdPartyMonad a
  } deriving ( Functor
             , Applicative
             , Monad
             , UL.MonadIO
             , O.MonadOrville Postgres.Connection
             , MonadThrow
             )

{-|
   If the user is using 'MonadUnliftIO', then it would be up to them to provide
   this instance for their own Monad. Later versions of UnliftIO provide a helper
   function for implementing this, but we would like to keep the dependency bounds
   as broad as possibly, so we can't use that helper here.
  -}
instance UL.MonadUnliftIO EndUserMonad where
  askUnliftIO =
    EndUserMonad $ do
      unlio <- UL.askUnliftIO
      pure $ UL.UnliftIO (UL.unliftIO unlio . runEndUserMonad)

{-|
   This is the 'MonadOrvilleControl' instance that a user would need to built if
   they are using 'MonadUnliftIO' as their lifting strategy. We would like this to
   be trivial enough that we could easily provide it in the documentation of a
   quick start tutorial.
  -}
instance O.MonadOrvilleControl EndUserMonad where
  liftWithConnection = OULIO.liftWithConnectionViaUnliftIO
  liftFinally = OULIO.liftFinallyViaUnliftIO

{-|
   The organization of the Orville typeclasses currently requires this orphan
   instance to be provided by the user for third-party monad's they are using.
   Although it is trivial and relatively innocent, we would prefer to avoid
   requiring orphan instances when using Orville or even introducing new users
   to the concept.
  -}
instance O.MonadOrvilleControl ThirdPartyMonad where
  liftWithConnection = OULIO.liftWithConnectionViaUnliftIO
  liftFinally = OULIO.liftFinallyViaUnliftIO

orvilleAction :: EndUserMonad ()
orvilleAction = TestDB.reset []

test_migrate :: TestTree
test_migrate =
  TestDB.withDb $ \getPool ->
    testGroup
      "UnliftIO"
      [ testCase "works" $ do
          pool <- getPool
          runThirdPartyMonad $
            O.runOrville (runEndUserMonad orvilleAction) (O.newOrvilleEnv pool)
      ]