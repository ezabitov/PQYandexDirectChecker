let
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
