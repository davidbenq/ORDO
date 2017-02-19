public with sharing class ORDO_ImportDataController {

	private Schema.SObjectType importObjectType;

	public List<String> importObjects {get;set;}

	public Document xmlDocument {get;set;}

	public String importObjectName {get;
		set
		{
			importObjectType = Schema.getGlobalDescribe().get(value);
			importObjectName = value;
		}
	}	

	public ORDO_ImportDataController() {		
		importObjects = getImportObjects();
		xmlDocument = new Document();
	}

	private List<String> getImportObjects(){
		List<String> objects = new List<String>();
		ORDO_Properties__c property = [SELECT Name,Value__c FROM ORDO_Properties__c WHERE Name ='Import Objects' LIMIT 1];
		if(property == null || String.isBlank(property.Value__c)){
			return null;
		}
		for(String element:property.Value__c.split(',')){
			if(String.isBlank(importObjectName)){
				importObjectName = element;
			}
			objects.add(element);
		}
		return objects;
	}

	public List<SelectOption> getObjectOptions(){
		List<SelectOption> options = new List<SelectOption>();
		for(String key:importObjects){
			options.add(new SelectOption(key,key));
		}
		return options;
	}

	public void importData(){
		xmlDocument.id = null;
		if(xmlDocument == null){
			ApexPages.addMessage(new ApexPages.message(ApexPages.severity.Error,'File is empty!'));
			return;
		}

		xmlDocument.AuthorId = UserInfo.getUserId();
   		xmlDocument.FolderId = UserInfo.getUserId(); 

   		Savepoint savePt = Database.setSavepoint();

		try{
			insert xmlDocument;
			ORDO_XmlDocumentParser parser = new ORDO_XmlDocumentParser();
			parser.setDataSource(xmlDocument);
			parser.setSobjectType(importObjectType);
			List<sObject> objects = parser.getSObjects();
			if(objects != null){
				insert objects;
				ApexPages.addMessage(new ApexPages.message(ApexPages.severity.INFO,'File uploaded successfully'));
			}else{
				ApexPages.addMessage(new ApexPages.message(ApexPages.severity.Error,'Error detected!'));
				Database.rollback(savePt);		
			}
		}catch(Exception ex){
			ApexPages.addMessage(new ApexPages.message(ApexPages.severity.Error,'Error detected! '+ex.getMessage()));
			Database.rollback(savePt);
		}
	}
}