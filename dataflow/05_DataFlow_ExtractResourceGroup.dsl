source(output(
		Correlationid as string,
		Operationname as string,
		Status as string,
		Eventcategory as string,
		Level as string,
		Time as string,
		Subscription as string,
		Eventinitiatedby as string,
		Resourcetype as string,
		Resourcegroup as string,
		Resource as string
	),
	allowSchemaDrift: true,
	validateSchema: false,
	ignoreNoFilesFound: false) ~> ActivityLogCSVStream
ActivityLogCSVStream split(Resourcegroup=='app-grp',
	disjoint: false) ~> SplitRows@(appgrpstream, otherstream)
SplitRows@appgrpstream sink(allowSchemaDrift: true,
	validateSchema: false,
	input(
		Correlationid as string,
		Operationname as string,
		Status as string,
		Eventcategory as string,
		Level as string,
		Time as timestamp,
		Subscription as string,
		Eventinitiatedby as string,
		Resourcetype as string,
		Resourcegroup as string,
		Resource as string
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
		Correlationid,
		Operationname,
		Status,
		Eventcategory,
		Level,
		Time,
		Subscription,
		Eventinitiatedby,
		Resourcetype,
		Resourcegroup,
		Resource
	)) ~> ActivityLogSink