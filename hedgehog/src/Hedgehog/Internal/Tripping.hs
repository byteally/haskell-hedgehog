{-# OPTIONS_HADDOCK not-home #-}
module Hedgehog.Internal.Tripping (
    tripping
  , trippingM
  ) where

import           Hedgehog.Internal.Property (MonadTest, Diff(..), success, failWith)
import           Hedgehog.Internal.Show (valueDiff, mkValue, showPretty)
import           Hedgehog.Internal.Source (HasCallStack, withFrozenCallStack)


-- | Test that a pair of encode / decode functions are compatible.
--
-- Given a printer from some type 'a -> b', and a parser with a
-- potential failure case 'b -> f a'. Ensure that a valid 'a' round
-- trips through the "print" and "parse" to yield the same 'a'.
--
-- For example, types __should__ have tripping 'Read' and 'Show'
-- instances.
--
-- @
-- trippingShowRead :: (Show a, Read a, Eq a, MonadTest m) => a -> m ()
-- trippingShowRead a = tripping a show readEither
-- @
tripping ::
     (MonadTest m, Applicative f, Show b, Show (f a), Eq (f a), HasCallStack)
  => a
  -> (a -> b)
  -> (b -> f a)
  -> m ()
tripping x encode decode =
  trippingM x (pure . encode) (pure . decode)


trippingM ::
     (MonadTest m, Applicative f, Show b, Show (f a), Eq (f a), HasCallStack)
  => a
  -> (a -> m b)
  -> (b -> m (f a))
  -> m ()
trippingM x encode decode = do
  let
    mx =
      pure x

  i <- encode x
  my <- decode i
  if mx == my
    then success
    else
      case valueDiff <$> mkValue mx <*> mkValue my of
        Nothing ->
          withFrozenCallStack $
            failWith Nothing $ unlines [
                "━━━ Original ━━━"
              , showPretty mx
              , "━━━ Intermediate ━━━"
              , showPretty i
              , "━━━ Roundtrip ━━━"
              , showPretty my
              ]

        Just diff ->
          withFrozenCallStack $
            failWith
              (Just $
                Diff "━━━ " "- Original" ") (" "+ Roundtrip" " ━━━" diff) $
              unlines [
                  "━━━ Intermediate ━━━"
                , showPretty i
                ]
