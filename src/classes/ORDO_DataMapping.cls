public class ORDO_DataMapping {
	/*
	*	This class is responsible for providing appropriate data conversion.
	*	Every new subclass should implements DataTransfer interface.
	*	Example of usage in ORDO_XmlDocumentParser.
	*	
	*	Short idea presentation:
	*		ORDO_DataMapping.DataTransfer dataTypeTransfer 
	*			= (ORDO_DataMapping.DataTransfer) dataTypesMapping.get(dataType).newInstance();
	*/
	public interface DataTransfer{
		Object transfer(String value);
	}

	public class StringDataTransfer implements DataTransfer{
		public Object transfer(String value){
			if(String.isBlank(value)){
				return null;
			}
			return value;
		}
	}

	public class IntegerDataTransfer implements DataTransfer{
		public Object transfer(String value){
			return Integer.valueOf(value);
		}
	}

	public class DoubleDataTransfer implements DataTransfer{
		public Object transfer(String value){
			return Double.valueOf(value);
		}
	}

	public class BooleanDataTransfer implements DataTransfer{
		private final String STRING_XML_TRUE = 'true';
		private final String STRING_XML_FALSE = 'false';
		public Object transfer(String value){
			if(!value.equals(STRING_XML_TRUE) && !value.equals(STRING_XML_FALSE)){
				return null;
			}

			return value.equals(STRING_XML_TRUE) ? true:false;
		}
	}

	public class DateDataTransfer implements DataTransfer{
		public Object transfer(String value){			
			return Date.parse(value);
		}
	}

	public class LocationDataTransfer implements DataTransfer{
		public Object transfer(String value){
			List<String> locations = value.split(',');
			if(locations.size() != 2){
				return null;
			}
			Double latitude = Double.valueOf(locations[0]);
			Double longitude = Double.valueOf(locations[1]);

			return Location.newInstance(latitude,longitude);	
		}
	}
}