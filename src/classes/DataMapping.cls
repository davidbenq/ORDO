public class DataMapping {
	/*
	* PLease catch exception [Type Exception] in caller class
	*/
	public interface DataTransfer{
		Object transfer(String value);
	}

	public class StringDataTransfer implements DataTransfer{
		public Object transfer(String value){
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