let
    fnSitelinkUrl = (sitelinkSetId as text) =>
    let
        auth = "Bearer "&token,
        sitelinkUrl = "https://api.direct.yandex.com/json/v5/sitelinks",
        sitelinkBody = "{""method"": ""get"",
            ""params"": {
                ""SelectionCriteria"":
                    {
                        ""Ids"": ["""&sitelinkSetId&"""]
                    },
                ""FieldNames"": [""Id"", ""Sitelinks""]
                }
            }",
        sourceSitelinks = Web.Contents(sitelinkUrl,
            [Headers = [
                #"Authorization"=auth,
                #"Accept-Language" = "ru",
                #"Content-Type" = "application/json; charset=utf-8",
                #"Client-Login" = clientlogin],
            Content = Text.ToBinary(sitelinkBody) ]),
        sitelinksJson = Json.Document(sourceSitelinks,65001),
        sitelinksJsonToTable = Record.ToTable(sitelinksJson),
        sitelinksExpand = Table.ExpandRecordColumn(sitelinksJsonToTable, "Value", {"SitelinksSets"}, {"Value.SitelinksSets"}),
        sitelinksExpand1 = Table.ExpandListColumn(sitelinksExpand, "Value.SitelinksSets"),
        sitelinksExpand2 = Table.ExpandRecordColumn(sitelinksExpand1, "Value.SitelinksSets", {"Sitelinks"}, {"Value.SitelinksSets.Sitelinks"}),
        sitelinksExpand3 = Table.ExpandListColumn(sitelinksExpand2, "Value.SitelinksSets.Sitelinks"),
        sitelinksExpand4 = Table.ExpandRecordColumn(sitelinksExpand3, "Value.SitelinksSets.Sitelinks", {"Href"}, {"Value.SitelinksSets.Sitelinks.Href"}),
        sitelinksDelOther = Table.SelectColumns(sitelinksExpand4,{"Value.SitelinksSets.Sitelinks.Href"}),
        sitelinksRenameCol = Table.RenameColumns(sitelinksDelOther,{{"Value.SitelinksSets.Sitelinks.Href", "SitelinkHref"}}),
        delUtmSitelinks = Table.SplitColumn(sitelinksRenameCol, "SitelinkHref", Splitter.SplitTextByDelimiter("?", QuoteStyle.Csv), {"SitelinkHref.1"}),
        changeSitelinksTypeToText = Table.TransformColumnTypes(delUtmSitelinks,{{"SitelinkHref.1", type text}}),
        renameSitelinksCol = Table.RenameColumns(changeSitelinksTypeToText,{{"SitelinkHref.1", "SitelinkHref"}})
    in
        renameSitelinksCol
in
    fnSitelinkUrl
