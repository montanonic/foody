module Table exposing
    ( AlteredField
    , ColumnValue(..)
    , Msg
    , Table
    , TableColumn
    , createColumn
    , createTable
    , expectFloat
    , expectString
    , getAlteredFieldData
    , update
    , updateWithEffects
    , viewTable
    )

import Html exposing (Html, button, div, input, text)
import Html.Attributes exposing (class, disabled, placeholder, step, type_, value)
import Html.Events exposing (onClick, onInput)
import List.Extra as ListE


type alias TableColumn =
    { name : String
    , columnType : ColumnValue
    , rawData : List String
    }


createColumn : String -> ColumnValue -> TableColumn
createColumn name expectedType =
    { name = name, columnType = expectedType, rawData = [] }



{- To insert into a table that allows row insertion, we simply render it with each column containing
   an extra field of raw data left blank. When inserting, we simple append another blank entry to
   each column.
-}


{-| Each TableColumn has a type it must declare for the field entries that it allows. This type
contains all supported values for column fields, and will be used to determine how the HTML cells
are rendered along with any custom behavior.
-}
type ColumnValue
    = String String
    | Float Float


valueToString : ColumnValue -> String
valueToString value =
    case value of
        String s ->
            s

        Float f ->
            String.fromFloat f


valueFromString : ColumnValue -> String -> ColumnValue
valueFromString expectedType str =
    case expectedType of
        String _ ->
            String str

        Float _ ->
            Float (String.toFloat str |> Maybe.withDefault 0.0)


expectString : ColumnValue
expectString =
    String ""


expectFloat : ColumnValue
expectFloat =
    Float 0


alterColumnEntry : Int -> ColumnValue -> TableColumn -> TableColumn
alterColumnEntry index newValue tableColumn =
    { tableColumn | rawData = ListE.setAt index (valueToString newValue) tableColumn.rawData }


getColumnValues : TableColumn -> List ColumnValue
getColumnValues column =
    column.rawData
        |> List.map (valueFromString column.columnType)


type alias Table =
    { name : String
    , columns : List TableColumn

    -- Allows inserting a new row of data, deleting rows of data, and altering rows of data. To
    -- achieve this, a List of the same size as the number of columns is stored, with each entry
    -- being the corresponding (by index) column's blank field.
    , alterable : Maybe (List String)
    }


createTable : String -> { alterable : Bool } -> List TableColumn -> Table
createTable name { alterable } columns =
    { name = name
    , alterable =
        if alterable then
            Just <| List.map (always "") columns

        else
            Nothing
    , columns = columns
    }


{-| Get's the respective columns data by name, or an empty list if it was not found.
-}
getColumnData : String -> Table -> List ColumnValue
getColumnData columnName table =
    ListE.find (\column -> column.name == columnName) table.columns
        |> Maybe.map
            (\column ->
                List.map (valueFromString column.columnType) column.rawData
            )
        |> Maybe.withDefault []


{-| This updates the field that is used when inserting new entries into a table.
-}
alterInsertionField : Int -> String -> Table -> Table
alterInsertionField columnIndex newValue table =
    case table.alterable of
        Nothing ->
            table

        Just fields ->
            { table | alterable = Just <| ListE.setAt columnIndex newValue fields }


alterTableEntry : String -> Int -> ColumnValue -> Table -> Table
alterTableEntry column index newValue table =
    let
        newColumns =
            ListE.updateIf (\{ name } -> name == column)
                (alterColumnEntry index newValue)
                table.columns
    in
    { table | columns = newColumns }



-- UPDATE


type Msg
    = AlterValue String Int ColumnValue String
    | AlterInsertionField Int String
    | InsertRow


type alias AlteredField =
    { tableName : String
    , columnName : String
    , columnIndex : Int
    , insertion : Bool
    }


{-| Get the field data from the table.
-}
getAlteredFieldData : Table -> AlteredField -> String
getAlteredFieldData table { columnName, columnIndex } =
    getColumnData columnName table
        |> ListE.getAt columnIndex
        |> Maybe.map valueToString
        |> Maybe.withDefault ""


updateWithEffects : (List ( AlteredField, String ) -> Cmd msg) -> Msg -> Table -> ( Table, Cmd msg )
updateWithEffects toMsg msg table =
    let
        ( newTable, alteredFields ) =
            update msg table
    in
    ( newTable
    , toMsg <|
        List.map
            (\alteredField -> ( alteredField, getAlteredFieldData newTable alteredField ))
            alteredFields
    )


update : Msg -> Table -> ( Table, List AlteredField )
update msg table =
    let
        altered : String -> Int -> AlteredField
        altered columnName index =
            { tableName = table.name, columnName = columnName, columnIndex = index, insertion = False }
    in
    case msg of
        AlterValue columnName index expectedType newValue ->
            ( alterTableEntry columnName index (valueFromString expectedType newValue) table
            , [ altered columnName index ]
            )

        AlterInsertionField columnIndex newValue ->
            ( alterInsertionField columnIndex newValue table, [] )

        InsertRow ->
            let
                newColumnsWithAlters : List ( TableColumn, AlteredField )
                newColumnsWithAlters =
                    List.indexedMap
                        (\index column ->
                            ( table.alterable
                                |> Maybe.andThen (ListE.getAt index)
                                |> Maybe.map
                                    (\newField -> { column | rawData = newField :: column.rawData })
                                |> Maybe.withDefault column
                            , altered column.name 0
                            )
                        )
                        table.columns

                newColumns =
                    List.map Tuple.first newColumnsWithAlters

                alteredFields =
                    newColumnsWithAlters
                        |> List.map Tuple.second
                        |> List.map (\alter -> { alter | insertion = True })
            in
            ( { table
                | alterable = Just <| List.map (always "") table.columns
                , columns = newColumns
              }
            , alteredFields
            )



-- VIEW


viewTable : Table -> Html Msg
viewTable table =
    let
        viewColumn : Int -> TableColumn -> Html Msg
        viewColumn columnIndex column =
            div [ class "column" ] <|
                (div [ class "name" ] [ input [ disabled True, value column.name ] [] ]
                    :: (if table.alterable /= Nothing then
                            [ viewInsertableValue column.columnType columnIndex ]

                        else
                            []
                       )
                    ++ (column
                            |> getColumnValues
                            |> List.indexedMap (viewColumnValue column.name)
                       )
                )

        viewColumnValue : String -> Int -> ColumnValue -> Html Msg
        viewColumnValue columnName index columnValue =
            let
                stringValue =
                    valueToString columnValue

                onInputHandler =
                    AlterValue columnName index columnValue
            in
            div [ class "value" ] [ viewValue columnValue stringValue onInputHandler ]

        -- For alterable tables, this is the field that you can insert with.
        viewInsertableValue : ColumnValue -> Int -> Html Msg
        viewInsertableValue expectedType columnIndex =
            let
                stringValue =
                    table.alterable |> Maybe.andThen (ListE.getAt columnIndex) |> Maybe.withDefault ""

                onInputHandler =
                    AlterInsertionField columnIndex
            in
            div [ class "value", class "insertable" ]
                [ viewValue expectedType stringValue onInputHandler ]

        -- Generic rendering of a value cell in table.
        viewValue : ColumnValue -> String -> (String -> Msg) -> Html Msg
        viewValue expectedType stringValue onInputHandler =
            let
                commonInput attrs =
                    input
                        ([ value stringValue
                         , onInput onInputHandler
                         , disabled (table.alterable == Nothing)
                         ]
                            ++ attrs
                        )
            in
            case expectedType of
                String _ ->
                    commonInput [ placeholder "any text" ] []

                Float _ ->
                    commonInput [ placeholder "3.14", type_ "number", step "0.01" ] []
    in
    div [ class "table" ]
        [ div [ class "name" ] [ text table.name ]
        , if table.alterable /= Nothing then
            button [ onClick InsertRow ] [ text "Insert Row" ]

          else
            -- Dummy render value that takes up no space (but does create a DOM object)
            div [ Html.Attributes.style "display" "none" ] []
        , div [ class "columns" ] <| List.indexedMap viewColumn table.columns
        ]
