let
directChecklist = (token as text, clientlogin as nullable text, allCampaigns as nullable text) =>
let
    auth = "Bearer "&token,
        clientlogin = if clientlogin = null
        then ""
        else clientlogin,

    allCampaigns = if allCampaigns = "YES" then """States"": [""ON""]" else "",
    loadGithub = (function as text) =>
        let
            sourceFn = Expression.Evaluate(
                Text.FromBinary(
                    Binary.Buffer(
                        Web.Contents("https://raw.githubusercontent.com/ezabitov/PQYandexDirectChecker/master/"&function&".m")
                    )
                ), #shared)
        in
            sourceFn,



    fnCampaignOptions = loadGithub("fnCampaignOptions"),
    fnCampaignServerResponse = loadGithub("fnCampaignServerResponse"),
    fnRejectedAds = loadGithub("fnRejectedAds"),
    fnSitelinkUrl = loadGithub("fnSitelinkUrl"),
    fnVCards = loadGithub("fnVCards"),

/*
––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
Подключение к Reports Api
––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
*/
    fieldNames = "CampaignId,Cost,AvgClickPosition,AvgImpressionPosition,Ctr",
    reportType = "CUSTOM_REPORT",
    dateFrom = Date.ToText(Date.AddDays(DateTime.Date(DateTime.LocalNow()), -31), "yyyy-MM-dd"),
    dateTo = Date.ToText(Date.AddDays(DateTime.Date(DateTime.LocalNow()), -1), "yyyy-MM-dd"),

// Обработка fieldNames
    newDirect = Text.Split(fieldNames, ","),
    directToTable = Table.FromList(newDirect, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
    plusFieldName = Table.AddColumn(directToTable, "Custom", each "<FieldNames>"&[Column1]&"</FieldNames>"),
    deleteInDirect = Table.SelectColumns(plusFieldName,{"Custom"}),
    transpotInDirect = Table.Transpose(deleteInDirect),
    mergeInDirect = Table.CombineColumns(transpotInDirect, Table.ColumnNames(transpotInDirect),Combiner.CombineTextByDelimiter("", QuoteStyle.None),"Merged"),
    fieldnamestextDirect = mergeInDirect[Merged]{0},
    reportName = reportType&"-"&dateFrom&"-"&dateTo&fieldnamestextDirect,


    urlReports = "https://api.direct.yandex.com/v5/reports",
    bodyDirectReports =
        "<ReportDefinition xmlns=""http://api.direct.yandex.com/v5/reports"">
        <SelectionCriteria>
        <DateFrom>"&dateFrom&"</DateFrom>
        <DateTo>"&dateTo&"</DateTo>
        </SelectionCriteria>
        "&fieldnamestextDirect&"
        <ReportName>"&reportName&"</ReportName>
        <ReportType>"&reportType&"</ReportType>
        <DateRangeType>CUSTOM_DATE</DateRangeType>
        <Format>TSV</Format>
        <IncludeVAT>YES</IncludeVAT>
        <IncludeDiscount>NO</IncludeDiscount></ReportDefinition>",
    sourceDirect = Web.Contents(urlReports,[
       Content = Text.ToBinary(bodyDirectReports) ,
       Headers = [
            #"Authorization"=auth ,
            #"Client-Login"=clientlogin,
            #"Accept-Language"="ru",
            #"Content-Type"="application/x-www-form-urlencoded",
            #"returnMoneyInMicros" = "false"]]),


    expandDirect = Table.FromColumns({Lines.FromBinary(sourceDirect,null,null,65001)}),
    expandByColumnDirect = Table.SplitColumn(expandDirect, "Column1", Splitter.SplitTextByDelimiter("#(tab)", QuoteStyle.Csv), {"Column1.1", "Column1.2", "Column1.3", "Column1.4", "Column1.5"}),
    delFirstRow = Table.Skip(expandByColumnDirect,1),
    delLastRow = Table.RemoveLastN(delFirstRow,1),
    firstRowToHeader = Table.PromoteHeaders(delLastRow, [PromoteAllScalars=true]),
    change1 = Table.ReplaceValue(firstRowToHeader,".",",",Replacer.ReplaceText,{"Cost", "AvgClickPosition", "AvgImpressionPosition", "Ctr"}),
    change2 = Table.ReplaceValue(change1,"--",null,Replacer.ReplaceValue,{"Cost", "AvgClickPosition", "AvgImpressionPosition", "Ctr"}),
    change3 = Table.TransformColumnTypes(change2,{{"Cost", type number}, {"AvgClickPosition", type number}, {"AvgImpressionPosition", type number}, {"Ctr", type number}}),
    addCostDay = Table.AddColumn(change3, "CostDay", each [Cost]/30),
    changeTypeCostDay = Table.TransformColumnTypes(addCostDay,{{"CostDay", type number}}),



/*
––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
Получаем список кампаний в аккаунте и формируем таблицу
––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
*/

    url = "https://api.direct.yandex.com/json/v5/campaigns",
    body = "{""method"": ""get"",
            ""params"": {
                ""SelectionCriteria"": {"&allCampaigns&"},
                ""FieldNames"": [""Id"", ""Name""]}
        }",
    userIdSource = Web.Contents(url,
        [Headers = [
            #"Authorization"=auth,
            #"Accept-Language" = "ru",
            #"Content-Type" = "application/json; charset=utf-8",
            #"Client-Login" = clientlogin],
        Content = Text.ToBinary(body) ]),

    jsonList = Json.Document(userIdSource,65001),
    campaignToTable = Record.ToTable(jsonList),
    deleteNameColumn = Table.RemoveColumns(campaignToTable,{"Name"}),
    expandValueCampaign = Table.ExpandRecordColumn(deleteNameColumn, "Value", {"Campaigns"}, {"Campaigns"}),
    expandCampaign = Table.ExpandListColumn(expandValueCampaign, "Campaigns"),
    expandCampaign1 = Table.ExpandRecordColumn(expandCampaign, "Campaigns", {"Id", "Name"}, {"Id", "Name"}),
    campIdToText = Table.TransformColumnTypes(expandCampaign1,{{"Id", type text}}),
    campaignIdToText = Table.TransformColumnTypes(campIdToText,{{"Id", type text}}),


    getFnRejectedAds = Table.AddColumn(campaignIdToText, "fnRejectedAds", each fnRejectedAds([Id], token, clientlogin)),
    expandFnRejectedAds = Table.ExpandTableColumn(getFnRejectedAds, "fnRejectedAds", {"countRejected"}, {"Отклоненные объявления"}),


    getFnCampaignOptions = Table.AddColumn(expandFnRejectedAds, "fnCampaignOptions", each fnCampaignOptions([Id], token, clientlogin)),
    expandFnCampaignOptions = Table.ExpandTableColumn(getFnCampaignOptions, "fnCampaignOptions",
        {"ADD_TO_FAVORITES", "REQUIRE_SERVICING", "SHARED_ACCOUNT_ENABLED", "DAILY_BUDGET_ALLOWED", "ENABLE_SITE_MONITORING", "ADD_METRICA_TAG", "ADD_OPENSTAT_TAG", "ENABLE_EXTENDED_AD_TITLE", "ENABLE_AREA_OF_INTEREST_TARGETING", "BudgetPercent", "Counter ID", "Email", "BidPercent", "LimitPercent", "BiddingStrategyNetwork", "BiddingStrategySearch", "DailyBudget.Mode", "DailyBudget.Amount"},
        {"В избранном", "Обслуживание менеджером", "Общий счет", "Дневной бюджет", "МониторингСайта", "yclid", "Openstat", "РасширенныйЗаголовок", "РасширенныйГеоТаргет", "БюджетДРФ", "НомерСчетчика", "Email", "ОграничениеСтавкиВсетях", "ПроцентБюджетаНаСети", "СтратегияВСетях", "СтратегияНаПоиске", "РаспределениеДневногоБюджета", "ДневнойБюджет"}),


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
    delAnotherVcards = Table.SelectColumns(checkVcards,{"CampaignId", "ВизиткаЗаполнена"}),
    campIdToText2 = Table.TransformColumnTypes(delAnotherVcards,{{"CampaignId", type text}}),
    campaignIdDistinct = Table.Distinct(campIdToText2, {"CampaignId"}),
    mergeVcards = Table.NestedJoin(expandFnCampaignOptions,{"Id"},campaignIdDistinct,{"CampaignId"},"NewColumn",JoinKind.LeftOuter),
    expandNewColumnVcards = Table.ExpandTableColumn(mergeVcards, "NewColumn", {"ВизиткаЗаполнена"}, {"ВизиткаЗаполнена"}),

    mergeDirect = Table.NestedJoin(expandNewColumnVcards ,{"Id"},changeTypeCostDay,{"CampaignId"},"NewColumn",JoinKind.LeftOuter),
    expandNewColumnDirect = Table.ExpandTableColumn(mergeDirect, "NewColumn", {"AvgClickPosition", "AvgImpressionPosition", "CostDay", "Ctr"}, {"AvgClickPosition", "AvgImpressionPosition", "РасходДень", "Ctr"}),

    fnToTable = Table.AddColumn(campIdToText, "Custom", each fnCampaignServerResponse([Id], token, clientlogin)),
    expandLinkChecker = Table.ExpandTableColumn(fnToTable, "Custom",
        {"Name", "Id", "Href", "SitelinkSetId", "State", "CampaignId", "HrefClean", "SitelinkHref", "Response.Sitelinks", "Response.Status"},
        {"Name.1", "AdId", "Href", "SitelinkSetId", "State", "CampaignId", "HrefClean", "SitelinkHref", "Response.Sitelinks", "Response.Status"}),
    checkProblem = Table.AddColumn(expandLinkChecker, "Problem?", each
        if [SitelinkHref] = null and [Response.Status] = 200
            then 0
            else
            if [Response.Sitelinks] = 200 and [Response.Status] = 200
                    then 0
                    else 1),
    groupCount = Table.Group(checkProblem, {"CampaignId"}, {{"Битые ссылки", each List.Sum([#"Problem?"]), type number}}),
    campIdToText3 = Table.TransformColumnTypes(groupCount,{{"CampaignId", type text}}),
    mergeLinkCheck = Table.NestedJoin(expandNewColumnDirect,{"Id"},campIdToText3,{"CampaignId"},"NewColumn",JoinKind.LeftOuter),
    expandLinkCheck = Table.ExpandTableColumn(mergeLinkCheck, "NewColumn", {"Битые ссылки"}, {"Битые ссылки"}),
    sortColumn = Table.ReorderColumns(expandLinkCheck,{"Id", "Name", "РасходДень", "AvgClickPosition", "AvgImpressionPosition", "Ctr", "Битые ссылки", "Отклоненные объявления", "В избранном", "Обслуживание менеджером", "Общий счет", "Дневной бюджет", "МониторингСайта", "yclid", "Openstat", "РасширенныйЗаголовок", "РасширенныйГеоТаргет", "БюджетДРФ", "НомерСчетчика", "Email", "ОграничениеСтавкиВсетях", "ПроцентБюджетаНаСети", "СтратегияВСетях", "СтратегияНаПоиске", "РаспределениеДневногоБюджета", "ДневнойБюджет", "ВизиткаЗаполнена"})
in
    sortColumn
in
    directChecklist
