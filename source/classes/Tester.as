package
{	
	import flash.display.*;
	import flash.net.*;
	import flash.events.*;
	import dupin.parsers.yaml.YAML;
	
	public class Tester extends Sprite
	{

		public function Tester()
		{
			trace("Tester::Tester()", "loading YAML");
			var loader:URLLoader = new URLLoader(new URLRequest("test.yaml"));
			loader.addEventListener(Event.COMPLETE, function(e:Event):void{
				
				trace("Tester::Tester()", "Loaded... parsing...");
				var o:* = YAML.decode(loader.data);

				var miner:Function = function(what:Object, index:int):void{
					for (var p:String in what)
					{
						for(var spaces:Array = [], i:int=0; i< index; i++) spaces.push("\t");
						trace(spaces.join(''), p, "=", what[p]);
						
						if (what[p].toString().indexOf("[object Object]") == 0)
						{
							miner(what[p], index+1);
						}
					}
				}
				miner(o, 0);
			})
		}

	}
}