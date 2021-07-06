module Table exposing (Msg, Table, TableColumn, createColumn, createTable, expectFloat, expectString, update, viewTable)

import Html exposing (Html, button, div, input, text)
import Html.Attributes exposing (class, disabled, step, type_, value)
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


update : Msg -> Table -> Table
update msg table =
    case msg of
        AlterValue columnName index expectedType newValue ->
            alterTableEntry columnName index (valueFromString expectedType newValue) table

        AlterInsertionField columnIndex newValue ->
            alterInsertionField columnIndex newValue table

        InsertRow ->
            { table
                | alterable = Just <| List.map (always "") table.columns
                , columns =
                    List.indexedMap
                        (\index column ->
                            table.alterable
                                |> Maybe.andThen (ListE.getAt index)
                                |> Maybe.map (\newField -> { column | rawData = newField :: column.rawData })
                                |> Maybe.withDefault column
                        )
                        table.columns
            }



-- VIEW


viewTable : Table -> Html Msg
viewTable table =
    div [ class "table" ]
        [ div [ class "name" ] [ text table.name ]
        , if table.alterable /= Nothing then
            button [ onClick InsertRow ] [ text "Insert Row" ]

          else
            -- Dummy render value that takes up no space (but does create a DOM object)
            div [ Html.Attributes.style "display" "none" ] []
        , div [ class "columns" ] <| List.indexedMap (viewColumn table) table.columns
        ]


viewColumn : Table -> Int -> TableColumn -> Html Msg
viewColumn table columnIndex column =
    div [ class "column" ]
        ((if table.alterable /= Nothing then
            [ viewInsertableValue table column.columnType columnIndex ]

          else
            []
         )
            ++ (column
                    |> getColumnValues
                    |> List.indexedMap (viewColumnValue table column.name)
               )
        )


viewColumnValue : Table -> String -> Int -> ColumnValue -> Html Msg
viewColumnValue table columnName index columnValue =
    let
        stringValue =
            valueToString columnValue

        onInputHandler =
            AlterValue columnName index columnValue
    in
    viewValue table columnValue stringValue onInputHandler


{-| For alterable tables, this is the field that you can insert with.
-}
viewInsertableValue : Table -> ColumnValue -> Int -> Html Msg
viewInsertableValue table expectedType columnIndex =
    let
        stringValue =
            table.alterable |> Maybe.andThen (ListE.getAt columnIndex) |> Maybe.withDefault ""

        onInputHandler =
            AlterInsertionField columnIndex
    in
    viewValue table expectedType stringValue onInputHandler


{-| Generic rendering of a value cell in table.
-}
viewValue : Table -> ColumnValue -> String -> (String -> Msg) -> Html Msg
viewValue table expectedType stringValue onInputHandler =
    let
        commonInput attrs =
            input
                ([ value stringValue
                 , onInput onInputHandler
                 , disabled (table.alterable == Nothing)
                 ]
                    ++ attrs
                )

        valueInput =
            case expectedType of
                String _ ->
                    commonInput [] []

                Float _ ->
                    commonInput [ type_ "number", step "0.01" ] []
    in
    div [ class "value" ] [ valueInput ]
