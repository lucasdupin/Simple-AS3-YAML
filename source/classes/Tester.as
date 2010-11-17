package
{	
	import flash.display.Sprite;
	import flash.net.URLLoader;
	import flash.net.URLRequest;
	import flash.events.Event;
	import dupin.parsers.yaml.YAML;
	
	public class Tester extends Sprite
	{

		public function Tester()
		{
			trace("Loading YAML");
			var urlLoader:URLLoader = new URLLoader(new URLRequest("test.yaml"));
			urlLoader.addEventListener(Event.COMPLETE, onLoadComplete);
		}
		
		public function onLoadComplete(e:Event):void
		{
			trace("Load completed, parsing.");
			var obj:Object = YAML.decode(e.target.data);
			
			recursiveTraceProperties(obj);
			
		}
		
		public function recursiveTraceProperties(obj:Object, depth:int = 0, textPadding:String = ""):void
		{
			if(depth > 5) return;
			
			for (var key:String in obj)
			{
				trace(textPadding + key + ": " + obj[key]);
				recursiveTraceProperties(obj[key], depth + 1, textPadding + "\t");
			}
		}

	}
}