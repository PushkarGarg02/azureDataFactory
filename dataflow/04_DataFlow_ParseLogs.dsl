source(output(
		{2024-07-20 21:38:08 10.0.0.4 GET / - 80 - 2.221.109.41 Mozilla/5.0+(Windows+NT+10.0;+Win64;+x64)+AppleWebKit/537.36+(KHTML} as string,
		{+like+Gecko)+Chrome/126.0.0.0+Safari/537.36 - 200 0 0 178} as string
	),
	allowSchemaDrift: true,
	validateSchema: false,
	ignoreNoFilesFound: false,
	skipLines: 4) ~> LogFileStream
LogFileStream select(mapColumn(
		logdata = {2024-07-20 21:38:08 10.0.0.4 GET / - 80 - 2.221.109.41 Mozilla/5.0+(Windows+NT+10.0;+Win64;+x64)+AppleWebKit/537.36+(KHTML}
	),
	skipDuplicateMapInputs: true,
	skipDuplicateMapOutputs: true) ~> RenameColumns
RenameColumns derive(logdata = split(logdata, " ")) ~> SplitLogData
SplitLogData derive(logDate = logdata[1],
		IPAddress = logdata[9],
		RequestMethod = logdata[4],
		RequestResource = logdata[5]) ~> MapColumns
MapColumns sink(allowSchemaDrift: true,
	validateSchema: false,
	input(
		LogDate as date,
		IPAddress as string,
		RequestMethod as string,
		RequestResource as string
	),
	deletable:false,
	insertable:true,
	updateable:false,
	upsertable:false,
	format: 'table',
	staged: true,
	allowCopyCommand: true,
	skipDuplicateMapInputs: true,
	skipDuplicateMapOutputs: true,
	errorHandlingOption: 'stopOnFirstError',
	mapColumn(
		LogDate = logDate,
		IPAddress,
		RequestMethod,
		RequestResource
	)) ~> WebLongSink