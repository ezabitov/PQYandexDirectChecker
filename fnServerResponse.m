let
    fnServerResponse = (urlList as text) =>
    let
        source = Web.Contents(urlList,[ManualStatusHandling={404}]),
        getMetadata = Value.Metadata(source)
    in
        getMetadata
in
    fnServerResponse
