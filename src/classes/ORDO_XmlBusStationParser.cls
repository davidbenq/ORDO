public class ORDO_XmlBusStationParser extends ORDO_XmlDocumentParser  {
	public ORDO_XmlBusStationParser(Document document) {
		super(document);S
	}

	public override List<SObject> getSObjects(){
		List<SObject> busStations = new List<SObject>();
		if(domDocument == null){
			return busStations;
		}

		Dom.XmlNode rootElement = domDocument.getRootElement();
		for(Dom.XmlNode child:rootElement.getChildElements()){
			busStations.add(nodeToSObject(child));
		}

		return busStations;
	}

	private ORDO_Bus_Station__c nodeToSObject(Dom.XmlNode child){
		ORDO_Bus_Station__c busStation = new ORDO_Bus_Station__c();
		busStation.Name = child.getChildElement('name',null).getText();
		busStation.Street__c = child.getChildElement('street',null).getText();
		System.debug(child.getChildElement('location',null).getText());

		Location loc = stringToGeolocation(child.getChildElement('location',null).getText());
		busStation.Location__Latitude__s = loc.getlatitude();
		busStation.Location__Longitude__s = loc.getlongitude();
		return busStation;
	}
}