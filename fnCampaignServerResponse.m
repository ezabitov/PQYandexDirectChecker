let
    fnServerResponse = (urlList as text) =>
    let
        source = Web.Contents(urlList,[ManualStatusHandling={404}]),
        getMetadata = Value.Metadata(source)
    in
        getMetadata,


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
        renameSitelinksCol,
 fnCampaignServerResponse = (campaignsId as text) =>
    let
        auth = "Bearer "&token,
        urlAds = "https://api.direct.yandex.com/json/v5/ads",
        bodyAds = "{""method"":
                    ""get"",
                        ""params"":
                            {""SelectionCriteria"":
                                {
                                    ""CampaignIds"": ["""&campaignsId&"""],
                                    ""States"": [""ON""]
                                },
                                ""FieldNames"": [""Id"", ""State"", ""CampaignId""],
                                ""TextAdFieldNames"": [""Href"", ""SitelinkSetId""],
                                ""TextImageAdFieldNames"": [""Href""]
                                }
                    }",

        getAds = Web.Contents(urlAds,
            [Headers = [#"Authorization"=auth,
                        #"Accept-Language" = "ru",
                        #"Content-Type" = "application/json; charset=utf-8",
                        #"Client-Login" = clientlogin],
            Content = Text.ToBinary(bodyAds) ]),
        jsonListAds = Json.Document(getAds,65001),
        jsonToTableAds = Record.ToTable(jsonListAds),
        expandValueAds = Table.ExpandRecordColumn(jsonToTableAds, "Value", {"Ads"}, {"Ads"}),
        expandAds = Table.ExpandListColumn(expandValueAds, "Ads"),
        expandAds1 = Table.ExpandRecordColumn(expandAds, "Ads",
            {"Id", "TextAd", "State", "CampaignId", "TextImageAd"},
            {"Id", "TextAd", "State", "CampaignId", "TextImageAd"}),
        expandHrefLinks = Table.ExpandRecordColumn(expandAds1, "TextAd",
            {"Href", "SitelinkSetId"},
            {"TextHref", "SitelinkSetId"}),
        expandTextImageHref = Table.ExpandRecordColumn(expandHrefLinks, "TextImageAd", {"Href"}, {"TextImageAd.Href"}),
        getOneHref = Table.AddColumn(expandTextImageHref, "Href", each if [TextHref] = null
            then [TextImageAd.Href]
            else [TextHref]),
        delAmotherHref = Table.RemoveColumns(getOneHref,{"TextHref", "TextImageAd.Href"}),
        sitelinkSetIdToText = Table.TransformColumnTypes(delAmotherHref,{{"SitelinkSetId", type text}}),

        duplicateHref = Table.DuplicateColumn(sitelinkSetIdToText, "Href", "HrefClean1"),
        deleteUtm = Table.SplitColumn(duplicateHref,"HrefClean1",Splitter.SplitTextByDelimiter("?", QuoteStyle.Csv),{"HrefClean"}),
        deleteHttps = Table.ReplaceValue(deleteUtm,"https://","",Replacer.ReplaceText,{"HrefClean"}),
        deleteHttp = Table.ReplaceValue(deleteHttps,"http://","",Replacer.ReplaceText,{"HrefClean"}),
        deleteColExHref = Table.SelectColumns(deleteHttp,{"HrefClean"}),
        distinctHref = Table.Distinct(deleteColExHref),
        hrefDelNull = Table.SelectRows(distinctHref, each [HrefClean] <> null),
        hrefFnToTable = Table.AddColumn(hrefDelNull, "Custom", each fnServerResponse([HrefClean])),
        expandHrefResponseStatus = Table.ExpandRecordColumn(hrefFnToTable, "Custom", {"Response.Status"}, {"Response.Status"}),

        deleteColExSitelinks = Table.SelectColumns(deleteHttp,{"SitelinkSetId"}),
        distinctSitelinks = Table.Distinct(deleteColExSitelinks),
        sitelinksDelNull = Table.SelectRows(distinctSitelinks, each [SitelinkSetId] <> null),
        sitelinksFnToTable = Table.AddColumn(sitelinksDelNull, "Custom", each fnSitelinkUrl([SitelinkSetId])),
        expandSitelinks = Table.ExpandTableColumn(sitelinksFnToTable, "Custom", {"SitelinkHref"}, {"SitelinkHref"}),
        expandSitelinksResponse = Table.AddColumn(expandSitelinks, "Пользовательская", each fnServerResponse([SitelinkHref])),
        expandSitelinksResponse1 = Table.ExpandRecordColumn(expandSitelinksResponse, "Пользовательская", {"Response.Status"}, {"Response.Sitelinks"}),

            // запускаем функцию и мерджим статусы URL с списком всех объявлений
        mergeSitelinks = Table.NestedJoin(deleteHttp,{"SitelinkSetId"},expandSitelinksResponse1,{"SitelinkSetId"},"mergeSitelinks",JoinKind.LeftOuter),
        mergeHref = Table.NestedJoin(mergeSitelinks,{"HrefClean"},expandHrefResponseStatus,{"HrefClean"},"mergeHref",JoinKind.LeftOuter),
        expandMergeSitelinks = Table.ExpandTableColumn(mergeHref, "mergeSitelinks",
            {"SitelinkHref", "Response.Sitelinks"},
            {"SitelinkHref", "Response.Sitelinks"}),
        expandMergeHref = Table.ExpandTableColumn(expandMergeSitelinks, "mergeHref", {"Response.Status"}, {"Response.Status"})

    in
        expandMergeHref
in
    fnCampaignServerResponse
