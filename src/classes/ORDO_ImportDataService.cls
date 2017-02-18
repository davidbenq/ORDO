public abstract class ORDO_ImportDataService {
	/*
	*	This map is responsible for proper data type mapping. It's references Apex sObjects data types to
	*	Apex data type by special class contained in ORDO_DataMapping namespace.
	*/
	protected final Map<Schema.DisplayType,Type> dataTypesMapping = new Map<Schema.DisplayType,Type> {
		Schema.DisplayType.String => ORDO_DataMapping.StringDataTransfer.class,
		Schema.DisplayType.Picklist => ORDO_DataMapping.StringDataTransfer.class,
		Schema.DisplayType.Phone => ORDO_DataMapping.StringDataTransfer.class,
		Schema.DisplayType.Integer => ORDO_DataMapping.IntegerDataTransfer.class,
		Schema.DisplayType.Double => ORDO_DataMapping.DoubleDataTransfer.class,
		Schema.DisplayType.Boolean => ORDO_DataMapping.BooleanDataTransfer.class,
		Schema.DisplayType.Date => ORDO_DataMapping.DateDataTransfer.class,
		Schema.DisplayType.Currency => ORDO_DataMapping.DoubleDataTransfer.class,
		Schema.DisplayType.Location => ORDO_DataMapping.LocationDataTransfer.class
	};

	public abstract void setDataSource(Object source);

	public abstract void setSObjectType(SObjectType sObjectType);

	public abstract List<SObject> getSObjects();
}