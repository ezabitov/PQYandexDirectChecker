let
fnCampaignOptions = (campaignId as text, token as text, clientlogin as nullable text) =>

let
    auth = "Bearer "&token,
    clientLogin = "",
    url = "https://api.direct.yandex.com/json/v5/campaigns",
    body = "{
        ""method"": ""get"",
        ""params"":
            {""SelectionCriteria"":
                {""Ids"": ["""&campaignId&"""]},
            ""FieldNames"": [""Id"", ""Name"", ""Notification"", ""DailyBudget""],
            ""TextCampaignFieldNames"": [""RelevantKeywords"", ""Settings"", ""CounterIds"", ""BiddingStrategy""]
        }}",
    userIdSource = Web.Contents(url,
        [Headers = [#"Authorization"=auth,
                    #"Accept-Language" = "ru",
                    #"Content-Type" = "application/json; charset=utf-8",
                    #"Client-Login" = clientlogin],
        Content = Text.ToBinary(body) ]),
    jsonList = Json.Document(userIdSource,65001),
    toTable = Table.FromRecords({jsonList}),
    expandCampaigns = Table.ExpandRecordColumn(toTable, "result", {"Campaigns"}, {"Campaigns"}),
    expandCampaigns1 = Table.ExpandListColumn(expandCampaigns, "Campaigns"),
    expandCampaigns2 = Table.ExpandRecordColumn(expandCampaigns1, "Campaigns", {"Name", "TextCampaign", "Id"}, {"Name", "TextCampaign", "Id"}),
    expandRelKey = Table.ExpandRecordColumn(expandCampaigns2, "TextCampaign", {"RelevantKeywords"}, {"RelevantKeywords"}),
    expandRelKey1 = Table.ExpandRecordColumn(expandRelKey, "RelevantKeywords", {"BudgetPercent", "OptimizeGoalId"}, {"BudgetPercent", "OptimizeGoalId"}),
    unpivotRelKey = Table.UnpivotOtherColumns(expandRelKey1, {"Name", "Id"}, "Option", "Value"),
    expandSettings = Table.ExpandRecordColumn(expandCampaigns2, "TextCampaign", {"Settings"}, {"Settings"}),
    expandSettings1 = Table.ExpandListColumn(expandSettings, "Settings"),
    expandSettings2 = Table.ExpandRecordColumn(expandSettings1, "Settings", {"Value", "Option"}, {"Value", "Option"}),
    expandCounter = Table.ExpandRecordColumn(expandCampaigns2, "TextCampaign", {"CounterIds"}, {"CounterIds"}),
    expandCounter1 = Table.ExpandRecordColumn(expandCounter, "CounterIds", {"Items"}, {"Items"}),
    expandCounter2 = Table.ExpandListColumn(expandCounter1, "Items"),
    addOptionToCounter = Table.AddColumn(expandCounter2, "Option", each "Counter ID"),
    renameItemsToValue = Table.RenameColumns(addOptionToCounter,{{"Items", "Value"}}),
    expandBidStrategy = Table.ExpandRecordColumn(expandCampaigns2, "TextCampaign", {"BiddingStrategy"}, {"BiddingStrategy"}),
    expandBidStrategy1 = Table.ExpandRecordColumn(expandBidStrategy, "BiddingStrategy", {"Network", "Search"}, {"Network", "Search"}),
    expandNetworkDefault = Table.ExpandRecordColumn(expandBidStrategy1, "Network", {"NetworkDefault", "BiddingStrategyType"}, {"NetworkDefault", "BiddingStrategyType"}),
    expandNetworkDefault1 = Table.ExpandRecordColumn(expandNetworkDefault, "NetworkDefault", {"BidPercent", "LimitPercent"}, {"BidPercent", "LimitPercent"}),
    renameNetworkBidSrat = Table.RenameColumns(expandNetworkDefault1,{{"BiddingStrategyType", "BiddingStrategyNetwork"}}),
    expandSearch = Table.ExpandRecordColumn(renameNetworkBidSrat, "Search", {"BiddingStrategyType"}, {"BiddingStrategyType.1"}),
    renameSearchBidStrat = Table.RenameColumns(expandSearch,{{"BiddingStrategyType.1", "BiddingStrategySearch"}}),
    unpivotStrategy = Table.UnpivotOtherColumns(renameSearchBidStrat, {"Name", "Id"}, "Option", "Value"),
    expandNotification = Table.ExpandRecordColumn(expandCampaigns1, "Campaigns", {"Name", "Notification", "Id"}, {"Name", "Notification", "Id"}),
    expandEmailSettings = Table.ExpandRecordColumn(expandNotification, "Notification", {"EmailSettings"}, {"EmailSettings"}),
    expandEmail = Table.ExpandRecordColumn(expandEmailSettings, "EmailSettings", {"Email"}, {"Email"}),
    addOptionEmail = Table.AddColumn(expandEmail, "Option", each "Email"),
    addValueEmail = Table.RenameColumns(addOptionEmail,{{"Email", "Value"}}),


    expandDailyBudget = Table.ExpandRecordColumn(expandCampaigns1, "Campaigns", {"Name", "Id", "DailyBudget"}, {"Name", "Id", "DailyBudget"}),
    expandDailyBudget2 = Table.ExpandRecordColumn(expandDailyBudget, "DailyBudget", {"Mode", "Amount"}, {"DailyBudget.Mode", "DailyBudget.Amount"}),
    budgetTypeChange = Table.TransformColumnTypes(expandDailyBudget2,{{"DailyBudget.Amount", Int64.Type}}),
    budgetToReal = Table.TransformColumns(#"Измененный тип", {{"DailyBudget.Amount", each _ / 1000000, type number}}),
    unpivotDailyBudget = Table.UnpivotOtherColumns(budgetToReal, {"Name", "Id"}, "Option", "Value"),
    append = Table.Combine({expandSettings2, unpivotRelKey, renameItemsToValue, addValueEmail, unpivotStrategy, unpivotDailyBudget}),
    delAnother = Table.SelectColumns(append,{"Value", "Option"}),
    transpotting = Table.Transpose(delAnother),
    desc = Table.Sort(transpotting,{{"Column1", Order.Ascending}}),
    upHeader = Table.PromoteHeaders(desc, [PromoteAllScalars=true])
in
    upHeader
in
    fnCampaignOptions
