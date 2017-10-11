let
fnRejectedAds = (campaignId as text) =>
let
    auth = "Bearer "&token,
    url = "https://api.direct.yandex.com/json/v5/ads",
    body = "{
        ""method"": ""get"",
        ""params"":
        {
            ""SelectionCriteria"":
            {
                ""CampaignIds"": ["""&campaignId&"""],
                ""Statuses"": [""REJECTED""]
                }, 
            ""FieldNames"": [""Id"", ""Status"", ""AdGroupId""]
        }
    }",
    userIdSource = Web.Contents(url,
        [Headers = [#"Authorization"=auth,
                    #"Accept-Language" = "ru",
                    #"Content-Type" = "application/json; charset=utf-8",
                    #"Client-Login" = ""],
        Content = Text.ToBinary(body) ]),
    jsonList = Json.Document(userIdSource,65001),
    rejectToTable = Record.ToTable(jsonList),
    expandReject1 = Table.ExpandRecordColumn(rejectToTable, "Value", {"Ads"}, {"Value.Ads"}),
    expandReject2 = Table.ExpandListColumn(expandReject1, "Value.Ads"),
    expandReject3 = Table.ExpandRecordColumn(expandReject2, "Value.Ads", {"Status", "Id", "AdGroupId"}, {"Value.Ads.Status", "Value.Ads.Id", "Value.Ads.AdGroupId"}),
    countSum = Table.AddColumn(expandReject3, "forSum", each if [Value.Ads.Id] = null then 0 else 1),
    countReject = Table.Group(countSum, {"Value.Ads.Status"}, {{"countRejected", each List.Sum([forSum]), type number}}),
    rejectDelAnotherCol = Table.SelectColumns(countReject,{"countRejected"})

in
    rejectDelAnotherCol
in
    fnRejectedAds
