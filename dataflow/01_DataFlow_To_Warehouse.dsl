source(output(
		SalesOrderID as integer,
		RevisionNumber as integer,
		OrderDate as timestamp,
		DueDate as timestamp,
		ShipDate as timestamp,
		Status as integer,
		OnlineOrderFlag as boolean,
		SalesOrderNumber as string,
		PurchaseOrderNumber as string,
		AccountNumber as string,
		CustomerID as integer,
		ShipToAddressID as integer,
		BillToAddressID as integer,
		ShipMethod as string,
		CreditCardApprovalCode as string,
		SubTotal as decimal(19,4),
		TaxAmt as decimal(19,4),
		Freight as decimal(19,4),
		TotalDue as decimal(19,4),
		Comment as string,
		rowguid as string,
		ModifiedDate as timestamp
	),
	allowSchemaDrift: true,
	validateSchema: false,
	isolationLevel: 'READ_UNCOMMITTED',
	format: 'table') ~> SalesOrderHeaderStream
source(output(
		SalesOrderID as integer,
		SalesOrderDetailID as integer,
		OrderQty as integer,
		ProductID as integer,
		UnitPrice as decimal(19,4),
		UnitPriceDiscount as decimal(19,4),
		LineTotal as decimal(38,6),
		rowguid as string,
		ModifiedDate as timestamp
	),
	allowSchemaDrift: true,
	validateSchema: false,
	isolationLevel: 'READ_UNCOMMITTED',
	format: 'table') ~> SalesOrderDetailStream
source(output(
		CustomerID as integer,
		NameStyle as boolean,
		Title as string,
		FirstName as string,
		MiddleName as string,
		LastName as string,
		Suffix as string,
		CompanyName as string,
		SalesPerson as string,
		EmailAddress as string,
		Phone as string,
		PasswordHash as string,
		PasswordSalt as string,
		rowguid as string,
		ModifiedDate as timestamp
	),
	allowSchemaDrift: true,
	validateSchema: false,
	isolationLevel: 'READ_UNCOMMITTED',
	query: 'Select * from SalesLT.Customer where CustomerID > 20000',
	format: 'query') ~> CustomerStream
source(output(
		ProductID as integer,
		Name as string,
		ProductNumber as string,
		Color as string,
		StandardCost as decimal(19,4),
		ListPrice as decimal(19,4),
		Size as string,
		Weight as decimal(8,2),
		ProductCategoryID as integer,
		ProductModelID as integer,
		SellStartDate as timestamp,
		SellEndDate as timestamp,
		DiscontinuedDate as timestamp,
		ThumbNailPhoto as binary,
		ThumbnailPhotoFileName as string,
		rowguid as string,
		ModifiedDate as timestamp
	),
	allowSchemaDrift: true,
	validateSchema: false,
	isolationLevel: 'READ_UNCOMMITTED',
	format: 'table') ~> ProductStream
source(output(
		ProductCategoryID as integer,
		ParentProductCategoryID as integer,
		Name as string,
		rowguid as string,
		ModifiedDate as timestamp
	),
	allowSchemaDrift: true,
	validateSchema: false,
	isolationLevel: 'READ_UNCOMMITTED',
	format: 'table') ~> ProductCategoryStream
source(output(
		maxCustomerSK as integer
	),
	allowSchemaDrift: true,
	validateSchema: false,
	isolationLevel: 'READ_UNCOMMITTED',
	query: 'SELECT max(CustomerSK) AS maxCustomerSK from dbo.dimCustomer',
	format: 'query',
	staged: true) ~> MaxCustomerSKStream
SalesOrderHeaderStream, SalesOrderDetailStream join(SalesOrderHeaderStream@SalesOrderID == SalesOrderDetailStream@SalesOrderID,
	joinType:'inner',
	matchType:'exact',
	ignoreSpaces: false,
	broadcast: 'auto')~> SalesOrderHeaderJoinSalesOrderDetail
SalesOrderHeaderJoinSalesOrderDetail select(mapColumn(
		SalesOrderID = SalesOrderHeaderStream@SalesOrderID,
		OrderDate,
		CustomerID,
		SubTotal,
		TaxAmt,
		Freight,
		TotalDue,
		OrderQty,
		ProductID,
		UnitPrice,
		UnitPriceDiscount,
		LineTotal
	),
	skipDuplicateMapInputs: true,
	skipDuplicateMapOutputs: true) ~> SelectColumns
CustomerStream select(mapColumn(
		CustomerID,
		CompanyName
	),
	skipDuplicateMapInputs: true,
	skipDuplicateMapOutputs: true) ~> SelectColumnsCustomer
ProductStream, ProductCategoryStream join(ProductStream@ProductCategoryID == ProductCategoryStream@ProductCategoryID,
	joinType:'inner',
	matchType:'exact',
	ignoreSpaces: false,
	broadcast: 'auto')~> ProductJoinProductCategory
ProductJoinProductCategory select(mapColumn(
		ProductID,
		ProductNumber,
		Color,
		ProductCategoryID = ProductStream@ProductCategoryID,
		ProductCategoryName = ProductCategoryStream@Name
	),
	skipDuplicateMapInputs: true,
	skipDuplicateMapOutputs: true) ~> selectColumnsProduct
selectColumnsProduct filter(!(isNull(Color))) ~> ColorFilter
SelectColumnsCustomer keyGenerate(output(CustomerSK as long),
	startAt: 1L,
	stepValue: 1L) ~> SurrogateCustomerKey
SurrogateCustomerKey derive(CustomerSK = CustomerSK + CacheSinkCustomerSK#outputs()[1].maxCustomerSK) ~> DeriveSurroagateCustomerSK
SelectColumns sink(allowSchemaDrift: true,
	validateSchema: false,
	deletable:false,
	insertable:true,
	updateable:false,
	upsertable:false,
	format: 'table',
	staged: true,
	allowCopyCommand: true,
	skipDuplicateMapInputs: true,
	skipDuplicateMapOutputs: true,
	errorHandlingOption: 'stopOnFirstError') ~> FactSalesStream
DeriveSurroagateCustomerSK sink(allowSchemaDrift: true,
	validateSchema: false,
	input(
		CustomerSK as integer,
		CustomerID as integer,
		CompanyName as string
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
		CustomerSK,
		CustomerID,
		CompanyName
	)) ~> DimCustomer
ColorFilter sink(allowSchemaDrift: true,
	validateSchema: false,
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
		ProductID,
		ProductNumber,
		Color,
		ProductCategoryID,
		ProductCategoryName
	)) ~> dimProduct
MaxCustomerSKStream sink(validateSchema: false,
	skipDuplicateMapInputs: true,
	skipDuplicateMapOutputs: true,
	store: 'cache',
	format: 'inline',
	output: false,
	saveOrder: 1) ~> CacheSinkCustomerSK