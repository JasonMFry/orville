{-|
Module    : Database.Orville.Internal.FieldUpdate
Copyright : Flipstone Technology Partners 2016-2018
License   : MIT
-}

{-# LANGUAGE FlexibleContexts #-}
module Database.Orville.Internal.FieldUpdate where

import            Data.Convertible
import            Database.HDBC

import            Database.Orville.Internal.FieldDefinition
import            Database.Orville.Internal.Types

fieldUpdate :: Convertible a SqlValue
            => FieldDefinition -> a -> FieldUpdate
fieldUpdate def = FieldUpdate def . convert

(.:=) :: Convertible a SqlValue => FieldDefinition -> a -> FieldUpdate
(.:=) = fieldUpdate

fieldUpdateName :: FieldUpdate -> String
fieldUpdateName = fieldName . fieldUpdateField
