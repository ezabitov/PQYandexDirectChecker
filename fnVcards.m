let
    fnVcards = (sitelinkSetId as text, token as text, clientlogin as nullable text) =>
    let
        auth = "Bearer "&token,
        urlVcards = "https://api.direct.yandex.com/json/v5/vcards",
        bodyVcards = "{""method"": ""get"", ""params"": {""FieldNames"": [""CampaignId"", ""Id"", ""Country"", ""City"", ""CompanyName"", ""Phone""]
                       }}",
        getVcards = Web.Contents(urlVcards,
            [Headers = [#"Authorization"=auth,
                        #"Accept-Language" = "ru",
                        #"Content-Type" = "application/json; charset=utf-8",
                        #"Client-Login" = clientlogin],
            Content = Text.ToBinary(bodyVcards) ]),
        jsonListVcards = Json.Document(getVcards ,65001),
        vcardsToTable = Table.FromRecords({jsonListVcards }),
        expandVcards = Table.ExpandRecordColumn(vcardsToTable , "result", {"VCards"}, {"VCards"}),
        expandVcards1 = Table.ExpandListColumn(expandVcards, "VCards"),
        expandVcards2 = Table.ExpandRecordColumn(expandVcards1, "VCards",
            {"Id", "Phone", "Country", "CampaignId", "CompanyName", "City"},
            {"Id", "Phone", "Country", "CampaignId", "CompanyName", "City"}),
        expandVcards3 = Table.ExpandRecordColumn(expandVcards2, "Phone",
            {"CountryCode", "CityCode", "PhoneNumber"},
            {"CountryCode", "CityCode", "PhoneNumber"}),
        checkVcards = Table.AddColumn(expandVcards3, "ВизиткаЗаполнена", each if
            [CountryCode] <> null and
            [CityCode] <> null and
            [PhoneNumber] <> null and
            [Country] <> null and
            [CampaignId] <> null and
            [CompanyName] <> null and
            [City] <> null
            then "Да" else "Нет"),
        delAnotherVcards = Table.SelectColumns(checkVcards,{"ВизиткаЗаполнена"}),
        distinctVcards = Table.Distinct(delAnotherVcards)

    in
        distinctVcards
in
    fnVcards
