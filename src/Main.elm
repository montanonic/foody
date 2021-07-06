{-
   Okay so my main goal, since I don't have pencil and paper, is to build up feature-by-feature into more complex parsing. We'll start with simple calculator arithmetic, and elaborate more deeply.

   So, initial goals:

   parse "3 + 7", and also with -, *, /
   parse the same, but with larger numbers
   parse the same, but with negative numbers

   Do all of this with a char-by-char UI? At least to get a feel for what that's like before discounting its power just because the elm parsing model already provides utilities for operating on larger chunks all at once.
-}


module Main exposing (Msg(..), main, update, view)

import Browser
import Debug
import Html exposing (Html, button, div, input, text)
import Html.Attributes exposing (class, type_, value)
import Html.Events exposing (onClick, onInput)
import Table exposing (ColumnValue(..), Table)



-- MAIN


main : Program () Model Msg
main =
    Browser.document { init = init, update = update, view = viewToDocument view, subscriptions = \_ -> Sub.none }



-- MODEL


type alias Model =
    { addIngredient : Ingredient
    , ingredients : List Ingredient
    , acquiredIngredients : Table
    }



-- type alias AcquiredIngredient r =
--     { r
--         | name : List String
--         , price : List Float
--         , amount : List String
--     }
-- alterAcquiredIngredientName idx value ingredient =
--     { ingredient | acquiredIngredientNames }


init : flags -> ( Model, Cmd Msg )
init _ =
    ( { addIngredient =
            { name = "", quantity = Count 0, expiration = "" }
      , ingredients =
            [ { name = "spinach", quantity = Weight "16oz", expiration = "5/17" }
            , { name = "eggs", quantity = Count 9, expiration = "6/22" }
            ]
      , acquiredIngredients =
            Table.createTable "Acquired Ingredients"
                { alterable = True }
                [ Table.createColumn "name" Table.expectString
                , Table.createColumn "price" Table.expectFloat
                ]
      }
    , Cmd.none
    )


initD : Model
initD =
    init {} |> Tuple.first


type alias Ingredient =
    { name : String
    , quantity : Quantity
    , expiration : String
    }



-- {-| Stock ingredients are what we have at the house, but Recipe Ingredients are the more "abstract"
-- ingredient that is found in a recipe. From these "abstract" entitites, we pull from ingredients that
-- we have in stock to determine how much you already have, and what's missing.
-- -}
-- type alias RecipeIngredient =
--     { name : String, quantity : Quantity }
-- type alias Recipe =
--     { name : String, ingredients : List RecipeIngredient }
-- {-| Ingredients are uniquely identified by combination of their name and expiration.
-- -}
-- ingredientId :
--     { a
--         | name : String
--         , expiration : String
--     }
--     -> ( String, String )
-- ingredientId ingredient =
--     ( ingredient.name, ingredient.expiration )


{-| Quantities are funny things, with Eggs we'll want to count the number of eggs, but with arugula
we'll want to keep track of the weight. And then some things use volume, so doing
weight-to-volume conversions could be useful, but we'll save that for later.
-}
type Quantity
    = Count Int
      -- We'll come up with a more useful signature later.
    | Weight String


setQuantity : Quantity -> Ingredient -> Ingredient
setQuantity q i =
    { i | quantity = q }



-- UPDATE


type Msg
    = NoOp
    | UpdateAcquiredIngredients Table.Msg
    | AddIngredient
    | AddIngredientQuantityIsCount
    | AddIngredientQuantityIsWeight
    | AddIngredientNameChange String
    | AddIngredientCountChange Int
    | AddIngredientWeightChange String
    | AddIngredientExpirationChange String


update : Msg -> Model -> ( Model, Cmd msg )
update msg model =
    ( Debug.log "model update"
        (case Debug.log "message" msg of
            NoOp ->
                model

            UpdateAcquiredIngredients tableMsg ->
                { model | acquiredIngredients = Table.update tableMsg model.acquiredIngredients }

            AddIngredient ->
                { model
                    | ingredients = model.addIngredient :: model.ingredients
                    , addIngredient = initD.addIngredient
                }

            AddIngredientQuantityIsCount ->
                updateAddIngredient (setQuantity (Count 0)) model

            AddIngredientQuantityIsWeight ->
                updateAddIngredient (setQuantity (Weight "")) model

            AddIngredientNameChange s ->
                updateAddIngredient (\i -> { i | name = s }) model

            AddIngredientCountChange n ->
                updateAddIngredient (setQuantity (Count n)) model

            AddIngredientWeightChange s ->
                updateAddIngredient (setQuantity (Weight s)) model

            AddIngredientExpirationChange s ->
                updateAddIngredient (\i -> { i | expiration = s }) model
        )
    , Cmd.none
    )


updateAddIngredient : (Ingredient -> Ingredient) -> Model -> Model
updateAddIngredient fn model =
    { model | addIngredient = fn model.addIngredient }



-- VIEW


type alias Document msg =
    { title : String
    , body : List (Html msg)
    }


viewToDocument : (Model -> Html Msg) -> Model -> Document Msg
viewToDocument viewFn model =
    { title = "Foody", body = [ viewFn model ] }


view : Model -> Html Msg
view model =
    div
        [ class "app" ]
        [ Html.map UpdateAcquiredIngredients <| Table.viewTable model.acquiredIngredients ]



-- [ addIngredients model.addIngredient
-- , ingredientsList model.ingredients
-- ]


addIngredients : Ingredient -> Html Msg
addIngredients currentIngredient =
    div [ class "row" ]
        [ text "Add ingredient: "
        , input [ onInput AddIngredientNameChange, value currentIngredient.name ] []
        , enterQuantity currentIngredient.quantity
        , button [ onClick AddIngredient ] [ text "Add" ]
        ]


enterQuantity : Quantity -> Html Msg
enterQuantity quantity =
    div [ class "row" ]
        (case quantity of
            Count n ->
                [ button [ onClick AddIngredientQuantityIsWeight ] [ text "Make Weight" ]
                , input
                    [ value (String.fromInt n)
                    , type_ "number"
                    , onInput (\s -> AddIngredientCountChange (String.toInt s |> Maybe.withDefault 0))
                    ]
                    []
                ]

            Weight s ->
                [ button [ onClick AddIngredientQuantityIsCount ] [ text "Make Count" ]
                , input
                    [ value s
                    , onInput AddIngredientWeightChange
                    ]
                    []
                ]
        )


ingredientsList : List Ingredient -> Html Msg
ingredientsList ingredients =
    div [] (List.map viewIngredient ingredients)


viewIngredient : Ingredient -> Html Msg
viewIngredient ingredient =
    div []
        [ text "Name: "
        , text ingredient.name
        , text " || "
        , case ingredient.quantity of
            Count n ->
                text ("Count: " ++ String.fromInt n)

            Weight s ->
                text ("Weight: " ++ s)
        , text " || "
        , text "Expiration: "
        , text ingredient.expiration
        ]
