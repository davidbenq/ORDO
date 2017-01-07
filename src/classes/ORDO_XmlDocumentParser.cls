public class ORDO_XmlDocumentParser {

	/*
	* Class: ORDO_XmlDocumentParser
	* Author[s]: Dawid Bieniek[dawidsfdc@gmail.com]
	* 
	* Class is responsible for parsing xml documents to sOBjects.
	* We are using here metadata approach, instead of doing single 
	* parse class for single object, here is a universal parser. 
	* Of course you need to follow some rules!
	* You need to provide XML Document(Standard SFDC Object Document), 
	* its transformed to Dom.Document. Also you need to provide objectType 
	* of sfdc object to which you want transform xml data.
	* Here is mapping between metadata field description and xml node name.
	* Its convenction
	*		Example 1:
	*			Field Name: example_field_name__c
	*			XML node name: examplefieldname
	*
	*		Example 2:
	*			Field Name: Name
	*			XML node name: name
	*
	* In simple words we make lowercase and later remove '_' or '__c' signs, then xml node can be 
	* associated with sobject field.
	* ss
	*/

	private static final String STRING_XML_TRUE = 'true';

	private static final String STRING_XML_FALSE = 'false';

	public static final String NAMESPACES_CONF = 'Namespaces';

	public static final Set<String> avaiableNamespaces = new Set<String>();

	public final SObjectType objectType {get;set;}

	public final Document document {get;set;}

	public final Dom.Document xmlDocument {get;set;}

	public final Map<String,Schema.SObjectField> sObjectFieldMap{get;set;}

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

	public ORDO_XmlDocumentParser(Document passedDocument,SObjectType passedObjectType) {
		document = passedDocument;
		objectType = passedObjectType;
		sObjectFieldMap = setSobjectFieldMap();
		xmlDocument = initializeXmlDocument();
		initializeXmlDocument();
		if(avaiableNamespaces.size() == 0){
			initializeAvailableNamespaces();
		}
	}

	private Map<String,Schema.SObjectField> setSobjectFieldMap(){
		if(objectType == null){
			throw new ORDO_XmlException('Object Type is null!');
		}
		DescribeSObjectResult describeResult = objectType.getDescribe();		
		Map<String,Schema.SObjectField> fieldMap = describeResult.fields.getMap();
		fieldMap = updateMapKeysToXmlEntries(fieldMap);		
		return fieldMap;	
	}

	private Map<String,Schema.SObjectField> updateMapKeysToXmlEntries(Map<String,Schema.SObjectField> mapToUpdate){
		Map<String,Schema.SObjectField> newMap = new Map<String,Schema.SObjectField>();
		for(String key:mapToUpdate.keySet()){
			String newKey = key.remove('__c').replace('_','').toLowerCase();			
			newMap.put(newKey,mapToUpdate.get(key));
		}
		return newMap;
	}	

	private Dom.Document initializeXmlDocument(){
		if(document == null){
			throw new ORDO_XmlException('Document is null!');
		}
		String domDocumentBody = document.Body.toString();					
		Dom.Document xmlDocument = new Dom.Document();
		xmlDocument.load(domDocumentBody);
		return xmlDocument;				
	}

	private Boolean isNamespaceAvailable(String namespace){
		if(avaiableNamespaces.size() == 0){
			initializeAvailableNamespaces();
		}
		return avaiableNamespaces.contains(namespace);
	}	

	private Boolean processXmlNode(Dom.XmlNode node,SObject parseObject,String allowedNamespace){
		if(node == null || parseObject == null){
			return false;
		}
		for(Dom.XmlNode elem:node.getChildElements()){
			if(!isNamespaceAvailable(elem.getNamespace())){
				return (Boolean) errorsHandler.registerError(elem.getNamespace()+' namespace is not allowed!',true,false);				
			}
			SObjectField field = sObjectFieldMap.get(elem.getName());
			if(field == null){
				return (Boolean) errorsHandler.registerError(elem.getName()+' no such field in '+objectType+' object!',true,false);				
			}
			String fieldName = field.getDescribe().getName();
			Schema.DisplayType dataType = field.getDescribe().getType();
			Object value = getDataValue(dataType,elem.getText());			
			if(dataType == Schema.DisplayType.Location && value != null){
				Location location = (Location) value;
				parseObject.put(fieldName.remove('__c')+'__Latitude__s',location.getLatitude());
				parseObject.put(fieldName.remove('__c')+'__Longitude__s',location.getLongitude());
			}else if(value != null){
				parseObject.put(fieldName,value);	
			}else{
				return (Boolean) errorsHandler.registerError('Value for: '+elem.getName()+' namespace['+elem.getNamespace()+'] is null!'
					,true,false);
			}			
		}
		return true;
	}

	private Object getDataValue(Schema.DisplayType dataType,String textValue){
		try{
			if(dataType == Schema.DisplayType.String || dataType == Schema.DisplayType.Picklist){
				return textValue;
			}else if(dataType == Schema.DisplayType.Integer){
				return Integer.valueOf(textValue);
			}else if(dataType == Schema.DisplayType.Double){
				return Double.valueOf(textValue);
			}else if(dataType == Schema.DisplayType.Location){
				return getLocationValue(textValue);			
			}else if(dataType == Schema.DisplayType.Boolean){
				return getBooleanValue(textValue);
			}else if(dataType == Schema.DisplayType.Date){
				return Date.parse(textValue);
			}
			else{
				return null;
			}
		}catch(TypeException ex){
			System.debug(ex.getMessage());
			return null;
		}
	}

	private Location getLocationValue(String stringLocation){
		List<String> locations = stringLocation.split(',');
		if(locations.size() != 2){
			return null;
		}
		try{
			Double latitude = Double.valueOf(locations[0]);
			Double longitude = Double.valueOf(locations[1]);
			return Location.newInstance(latitude,longitude);
		}catch(TypeException ex){
			System.debug(ex.getMessage());
			return null;
		}		
	}

	private Boolean getBooleanValue(String stringBoolean){
		if(!stringBoolean.equals(STRING_XML_TRUE) && !stringBoolean.equals(STRING_XML_FALSE)){
			return null;
		}
		return stringBoolean.equals(STRING_XML_TRUE) ? true:false;
	}

	public List<SObject> getSObjects(){		
		List<SObject> parsedObjects = new List<SObject>();
		Dom.XmlNode rootNode = xmlDocument.getRootElement();
		String namespace = rootNode.getNamespace();
		errorsHandler = new ErrorsHandler();
		if(String.isBlank(namespace) || !isNamespaceAvailable(namespace)){
			errorsHandler.registerError(namespace+' is not avaiable or is blank!',true,null);	
			return null;		
		}
		for(Dom.XmlNode childNode:rootNode.getChildElements()){
			SObject parseObject = objectType.newSObject();
			if(!isNamespaceAvailable(childNode.getNamespace()) || !processXmlNode(childNode,parseObject,namespace)){
				return null;
			}else{
				parsedObjects.add(parseObject);
			}
		}
		return parsedObjects; 
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

		public Object registerError(String error,Boolean debugOutput,Object returnValue){
			errors.add(error);
			if(debugOutput){
				System.debug(debugOutput);
			}

			return returnValue;
		}
	} 
}