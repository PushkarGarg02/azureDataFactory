source(output(
		customerid as integer,
		customername as string,
		registered as boolean,
		courses as string[],
		details as (mobile as string, city as string)
	),
	allowSchemaDrift: true,
	validateSchema: false,
	ignoreNoFilesFound: false,
	documentForm: 'arrayOfDocuments') ~> CustomerArrayJsonStream
CustomerArrayJsonStream foldDown(unroll(courses, courses),
	mapColumn(
		courses,
		mobile = details.mobile,
		city = details.city,
		CustomerID = customerid,
		CustomerName = customername,
		Registered = registered
	),
	skipDuplicateMapInputs: false,
	skipDuplicateMapOutputs: false) ~> FlattenCustomerCoursesArray
FlattenCustomerCoursesArray sink(allowSchemaDrift: true,
	validateSchema: false,
	input(
		CustomerID as integer,
		CustomerName as string,
		Registered as boolean,
		Courses as string,
		Mobile as string,
		City as string
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
		CustomerID,
		CustomerName,
		Registered,
		Courses = courses,
		Mobile = mobile,
		City = city
	)) ~> CustomerCourseArrayJsonSinkToPoolDB