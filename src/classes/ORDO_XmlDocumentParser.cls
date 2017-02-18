public class ORDO_XmlDocumentParser extends ORDO_ImportDataService {

	/*
	*	Class: ORDO_XmlDocumentParser
	*	Author[s]: Dawid Bieniek[dawidsfdc@gmail.com]
	* 
	*	Class is responsible for parsing xml documents to sOBjects.
	* 	We are using here metadata approach, instead of doing single 
	* 	parse class for single object, here is a universal parser. 
	* 	Of course you need to follow some rules!
	* 	You need to provide XML Document(Standard SFDC Object Document), 
	* 	its transformed to Dom.Document. Also you need to provide objectType 
	* 	of sfdc object to which you want transform xml data.
	* 	Here is mapping between metadata field description and xml node name.
	* 	Its convenction
	*		Example 1:
	*			Field Name: example_field_name__c
	*			XML node name: examplefieldname
	*
	*		Example 2:
	*			Field Name: Name
	*			XML node name: name
	*
	* 	In simple words we make lowercase and later remove '_' or '__c' signs, then xml node can be 
	* 	associated with sobject field.
	* 
	*/		

	public static final String NAMESPACES_CONF = 'Namespaces';

	public static final Set<String> avaiableNamespaces = new Set<String>();

	public SObjectType objectType {get;set;}

	public Document document {get;set;}

	public Dom.Document xmlDocument {get;set;}

	public Map<String,Schema.SObjectField> sObjectFieldMap{get;set;}

	public ErrorsHandler errorsHandler;


	public static void initializeAvailableNamespaces(){		
		ORDO_Properties__c property = [SELECT Name,Value__c FROM ORDO_Properties__c WHERE Name =:NAMESPACES_CONF LIMIT 1];		
		if(property == null || String.isBlank(property.Value__c)){
			return;
		}
		for(String element:property.Value__c.split(',')){
			avaiableNamespaces.add(element.toLowerCase());
		}
	}

	public static Set<String> listXMLEntriesForAccountFields(SObjectType objectType){		
		DescribeSObjectResult describeResult = objectType.getDescribe();		
		Map<String,Schema.SObjectField> fieldMap = describeResult.fields.getMap();
		return updateMapKeysToXmlEntries(fieldMap).keySet();
	}

	private static Map<String,Schema.SObjectField> updateMapKeysToXmlEntries(Map<String,Schema.SObjectField> mapToUpdate){
		Map<String,Schema.SObjectField> newMap = new Map<String,Schema.SObjectField>();
		for(String key:mapToUpdate.keySet()){
			String newKey = key.remove('__c').replace('_','').toLowerCase();			
			newMap.put(newKey,mapToUpdate.get(key));
		}

		return newMap;
	}

	public ORDO_XmlDocumentParser() {		
		errorsHandler = new ErrorsHandler();		
		if(avaiableNamespaces.size() == 0){
			initializeAvailableNamespaces();
		}
	}

	private Map<String,Schema.SObjectField> setSobjectFieldMap(){
		if(objectType == null){
			errorsHandler.registerError('ObjectType is null!',true);
			return null;
		}
		DescribeSObjectResult describeResult = objectType.getDescribe();		
		Map<String,Schema.SObjectField> fieldMap = describeResult.fields.getMap();
		fieldMap = updateMapKeysToXmlEntries(fieldMap);	

		return fieldMap;	
	}		

	private Dom.Document initializeXmlDocument(){
		if(document == null){
			errorsHandler.registerError('Document is null!',true);
			return null;
		}

		try{
			String domDocumentBody = document.Body.toString();					
			Dom.Document xmlDocument = new Dom.Document();
			xmlDocument.load(domDocumentBody);
			return xmlDocument;	
		}catch(XmlException ex){			
			errorsHandler.registerError('Problem with transform to XML document occur',true);
			throw new ORDO_XmlException(ex.getMessage(),ex);
		}					
	}

	private Boolean isNamespaceAvailable(String namespace){
		if(avaiableNamespaces.size() == 0){
			initializeAvailableNamespaces();
		}

		return avaiableNamespaces.contains(namespace);
	}	

	/*
	*	In Salesforce we are not able to put Location field directly,
	*	We need to pass field by __Latitude__s and __Longitude__s indirectly
	*	values.
	*/
	private Boolean processXmlNode(Dom.XmlNode node,SObject parseObject){
		if(node == null || parseObject == null){
			return false;
		}
		for(Dom.XmlNode elem:node.getChildElements()){

			if(!isNamespaceAvailable(elem.getNamespace())){
				errorsHandler.registerError(elem.getNamespace()+' namespace is not allowed!',true);				
				return false;
			}

			SObjectField field = sObjectFieldMap.get(elem.getName());			
			if(field == null){
				errorsHandler.registerError(elem.getName()+' no such field in '+objectType+' object!',true);
				return false;				
			}

			String fieldName = field.getDescribe().getName();
			Schema.DisplayType dataType = field.getDescribe().getType();
			Object value = getDataValue(dataType,elem.getText());

			if(dataType == Schema.DisplayType.Location && value != null){
				Location location = (Location) value;
				parseObject.put(fieldName.remove('__c')+'__Latitude__s',location.getLatitude());
				parseObject.put(fieldName.remove('__c')+'__Longitude__s',location.getLongitude());
			}else if(dataType == Schema.DisplayType.Picklist && value != null){
				if(isPicklistValueAvailable(field,(String) value)){
					parseObject.put(fieldName,value);
				}else{
					errorsHandler.registerError('No such picklist value['+value+'] for: '+fieldName,true);
					return false;
				}
			}else if(value != null){

				parseObject.put(fieldName,value);	
			}else{
				errorsHandler.registerError('Value for: '+elem.getName()+' namespace['+elem.getNamespace()+'] is null!',true);
				return false;
			}			
		}

		return true;
	}

	/*
	*	This function make data packaging.
	*	From xml we are able to get string value only.
	*	Here we can do maping thanks to current field data type and text value
	*	If object which you want to parse have unsupported data type you can define
	*	maping here.
	*
	*	It's achieved by using Type apex class and polymorphism.
	*/
	private Object getDataValue(Schema.DisplayType dataType,String textValue){				
		try{
			ORDO_DataMapping.DataTransfer dataTypeTransfer = (ORDO_DataMapping.DataTransfer) dataTypesMapping.get(dataType).newInstance();
			return dataTypeTransfer.transfer(textValue);
		}catch(TypeException ex){
			errorsHandler.registerError(ex.getMessage(),true);
			return null;
		}catch(NullPointerException ex){
			errorsHandler.registerError('Probably not appropriate data type mapping found, details: '+ex.getMessage(),true);
			return null;
		}
	}

	private Boolean isPicklistValueAvailable(SObjectField field,String picklistValue){
		Schema.DescribeFieldResult fieldDescription = field.getDescribe();
		List<Schema.PicklistEntry> picklistEntries = fieldDescription.getPicklistValues();
		for(Schema.PicklistEntry entry:picklistEntries){
			if(entry.getValue().equals(picklistValue)){
				return true;
			}
		}
		return false;
	}

	public override List<SObject> getSObjects(){		
		if(xmlDocument == null || objectType == null){
			return null;
		}

		List<SObject> parsedObjects = new List<SObject>();		
		Dom.XmlNode rootNode = xmlDocument.getRootElement();
		String namespace = rootNode.getNamespace();
	
		if(String.isBlank(namespace) || !isNamespaceAvailable(namespace)){
			errorsHandler.registerError(namespace+' is not avaiable or is blank!',true);	
			return null;		
		}
		for(Dom.XmlNode childNode:rootNode.getChildElements()){
			SObject parseObject = objectType.newSObject();
			if(!isNamespaceAvailable(childNode.getNamespace()) || !processXmlNode(childNode,parseObject)){
				return null;
			}else{
				parsedObjects.add(parseObject);
			}
		}

		return parsedObjects; 
	}

	public override void setDataSource(Object dataSource){		
		if(document != null){
			System.debug('Document has been already set!');
		}else if(!(dataSource instanceof Document)){
			System.debug('Incorrect data source!');
		}else{
			document = (Document) dataSource;
			xmlDocument = initializeXmlDocument();	
		}
	}

	public override void setSObjectType(SObjectType sObjectType){
		if(objectType != null){
			System.debug('ObjectType has been already set!');
		}else{
			objectType = sObjectType;
			sObjectFieldMap = setSobjectFieldMap();
		}
	}

	public class ErrorsHandler{
		public final List<String> errors{set;get;}
		public Boolean errorsOccur{					
			set{				
				if(!errorsOccur){
					errorsOccur = value;
				}
			}
			get;}
		public ErrorsHandler(){
			errors = new List<String>();
		}	

		public void registerError(String error,Boolean debugOutput){
			errors.add(error);
			if(debugOutput){
				System.debug(error);
			}
		}
	} 
}