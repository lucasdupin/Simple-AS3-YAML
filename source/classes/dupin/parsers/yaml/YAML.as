package dupin.parsers.yaml
{	
	
	/**
	* Small YAML parser
	* based on TJ Holowaychuk's <tj@vision-media.ca> work
	* 
	* @langversion ActionScript 3
	* @playerversion Flash 9.0.0
	* 
	* @author Lucas Dupin
	* @since  04.11.2010
	*/
	public class YAML
	{
		/**
		 * YAML grammar tokens.
		 */
		protected const _grammarTokens:Vector.<GrammarToken> = new <GrammarToken>
		[
			new GrammarToken('comment', /^#[^\n]*/),
			new GrammarToken('indent', /^\n(\s*)/),
			new GrammarToken('space', /^\s+/),
			new GrammarToken('true', /^(enabled|true|yes|on)/),
			new GrammarToken('false', /^(disabled|false|no|off)/),
			new GrammarToken('string', /^["|'](.*?)["|']/),           //' Duh, syntax highlighting
			new GrammarToken('multilineString', /^\|\s*/),
			new GrammarToken('float', /^(\d+\.\d+)/),
			new GrammarToken('int', /^(\d+)/),
			new GrammarToken('id', /^([\w ]+)\s*:/),                  // highlighting again
			new GrammarToken('doc', /^---/),
			new GrammarToken(',', /^,/),
			new GrammarToken('{', /^\{/),
			new GrammarToken('}', /^\}/),
			new GrammarToken('[', /^\[/),
			new GrammarToken(']', /^\]/),
			new GrammarToken('-', /^\-/),
			new GrammarToken(':', /^[:]/),
			new GrammarToken('string', /^(.*)/)
		]
		
		protected var _tokens:Array;
		

		public function YAML(yaml:String)
		{
			yaml = preProcess(yaml);
			_tokens = tokenize(yaml);
			trace("----------------------------------------- (error)")
			trace(_tokens.join("\n"));
			trace("----------------------------------------- (warning)")
		}
		
		public static function decode(str:String):*
		{
			return new YAML(str).parse();
		}
		
		public function preProcess(yaml:String):String
		{ 
			// Remove comments
			//yaml = yaml.replace(/#[^\"\'\n]+$/gm, "");

			// Removes empty lines
			yaml = yaml.replace(/^\s*$\n/gm, "");

			// Remove white characters before line breaks (trailing spaces)
			yaml = yaml.replace(/\s+$/gm, "");

			//trace(yaml);
			return yaml;
		}
		
		/**
		 * Formats String for proper error output.
		 * @param str * 
		 * @return String 
		 */
		private function context(str:*):String
		{
			if (!(str is String)) return '';
			str = str
			  .slice(0, 25)
			  .replace(/\n/g, '\\n')
			  .replace(/"/g, '\\\"')
			return 'near "' + str + '"'
		}
		
		/**
		 * Look-ahead a single token.
		 *
		 * @return {array}
		 * @api public
		 */
		protected function peek():Array
		{
			return _tokens[0];
		}

		/**
		 * Advance by a single token.
		 *
		 * @return {array}
		 * @api public
		 */
		protected function advance():Array
		{
		  return _tokens.shift();
		}
		
		/**
		 * Advance and return the token's value.
		 *
		 * @return {mixed}
		 * @api private
		 */
		private function advanceValue():*
		{
			return this.advance()[1][1];
		}
		
		/**
		 * Accept _type_ and advance or do nothing.
		 *
		 * @param  {string} type
		 * @return {bool}
		 * @api private
		 */
		protected function accept(type:String):*
		{
			if (this.peekType(type))
				return this.advance();
			
			//if(_tokens[0] == undefined)
			//			{
			//				trace("error: undefined tokens found!!")
			//				return true;
			//			}
			
			return false;
		}

		/**
		 * Expect _type_ or throw an error _msg_.
		 *
		 * @param  {string} type
		 * @param  {string} msg
		 * @api private
		 */
		protected function expect(type:String, msg:String):void
		{
			if (accept(type)) return;
		
			throw new Error(msg + (this.peek() ? ', ' + context(this.peek()[1].input) : ''));
		}

		/**
		 * Return the next token type.
		 *
		 * @return {string}
		 * @api private
		 */
		protected function peekType(val:String):Boolean
		{
		  return _tokens[0] &&
		         _tokens[0][0] === val;
		}

		/**
		 * space*
		 */
		protected function ignoreSpace():void {
			while (this.peekType('space'))
		    	this.advance();
		}

		/**
		 * (space | indent | dedent)*
		 */
		protected function ignoreWhitespace():void {
		  while (this.peekType('space') ||
		         this.peekType('indent') ||
		         this.peekType('dedent'))
		    this.advance();
		}

		/**
		 *   block
		 * | doc
		 * | list
		 * | inlineList
		 * | hash
		 * | inlineHash
		 * | string
		 * | multilineString
		 * | float
		 * | int
		 * | true
		 * | false
		 */

		protected function parse():*
		{
			switch (this.peek()[0]) {
				case 'doc':
					return this.parseDoc();
				case '-':
					return this.parseList();
				case '{':
					return this.parseInlineHash();
				case '[':
					return this.parseInlineList();
				case 'id':
					return this.parseHash();
				case 'multilineString':
					return this.parseMultilineString();
				case 'string':
					return this.advanceValue();
				case 'float':
					return parseFloat(this.advanceValue());
				case 'int':
					return parseInt(this.advanceValue());
				case 'true':
					this.advance();
					return true;
				case 'false':
					this.advance();
					return false;
			}
		}

		/**
		 * '---'? indent expr dedent
		 */

		protected function parseDoc():*
		{
			this.accept('doc');
			this.expect('indent', 'expected indent after document');
			var val:* = this.parse();
			this.expect('dedent', 'document not properly dedented');
			return val;
		}

		/**
		 *  ( id ':' - expr -
		 *  | id ':' - indent expr dedent
		 *  )+
		 */

		protected function parseHash():Object
		{
			var id:*, hash:Object = {}
			while (this.peekType('id') && (id = this.advanceValue()))
			{
				this.expect(':', 'expected semi-colon after id');
				this.ignoreSpace();
				if (this.accept('indent'))
					hash[id] = this.parse(),
					this.expect('dedent', 'hash not properly dedented')
				else
					hash[id] = this.parse();
				this.ignoreSpace();
			}
			return hash;
		}

		/**
		 * '{' (- ','? ws id ':' - expr ws)* '}'
		 */

		protected function parseInlineHash():Object {
		  var hash:Object = {}, id:*, i:int = 0
		  this.accept('{')
		  while (!this.accept('}')) {
		    this.ignoreSpace()
		    if (i) this.expect(',', 'expected comma')
		    this.ignoreWhitespace()
		    if (this.peekType('id') && (id = this.advanceValue())) {
		      this.expect(':', 'expected semi-colon after id')
		      this.ignoreSpace()
		      hash[id] = this.parse()
		      this.ignoreWhitespace()
		    }
		    ++i
		  }
		  return hash
		}
		
		
		/**
		 * '{' (- ','? ws id ':' - expr ws)* '}'
		 */

		protected function parseMultilineString():String {
			var result:String="";
			this.advanceValue(); //ignore first | (pipe)
			while (!this.accept('dedent')) {
				this.ignoreWhitespace();
				//trace(result, _tokens[0]);
				result += this.advanceValue() + "\n";
			}
			//Remove last space
			result = result.substr(0, result.length-1);
			
			return result;
		}

		/**
		 *  ( '-' - expr -
		 *  | '-' - indent expr dedent
		 *  )+
		 */

		protected function parseList():Array
		{
			var list:Array = [];
			while (this.accept('-')) {
				this.ignoreSpace();
				
				if (this.accept('indent'))
					list.push(this.parse()),
					this.expect('dedent', 'list item not properly dedented')
				else
					list.push(this.parse());
					
				this.ignoreSpace();
			}
			return list;
		}

		/**
		 * '[' (- ','? - expr -)* ']'
		 */

		protected function parseInlineList():Array {
		  var list:Array = [], i:int = 0;
		  this.accept('[')
		  while (!this.accept(']')) {
		    this.ignoreSpace()
		    if (i) this.expect(',', 'expected comma')
		    this.ignoreSpace()
		    list.push(this.parse())
		    this.ignoreSpace()
		    ++i
		  }
		  return list
		}
		
		
		/**
		 * Tokenize the given _str_.
		 *
		 * @param  {string} str
		 * @return {array}
		 * @api private
		 */

		protected function tokenize(str:String):Array {
		  var token:Array, captures:Array, ignore:Boolean, input:*,
		      indents:int = 0, lastIndents:int = 0,
		      stack:Array = [];
		
		  while (str.length) {
		    for (var i:int = 0, len:int = _grammarTokens.length; i < len; ++i)
		      if ((captures = _grammarTokens[i].regex.exec(str)) != null) {
		        token = [_grammarTokens[i].id, captures],
						str = str.replace(_grammarTokens[i].regex, '');
						
						//Modified id regexp, so it will consider ':', avoiding confusion with strings
						if(_grammarTokens[i].id == 'id')
		        	str = ':' + str;
							
		        switch (token[0]) {
		          case 'comment':
		            ignore = true
		            break;
		          case 'indent':
		            lastIndents = indents
		            indents = token[1][1].length / 2
		            if (indents === lastIndents)
		              ignore = true
		            else if (indents > lastIndents + 1)
							token[1][1] = token[1][1].substr(0, lastIndents);
		              //throw new SyntaxError('invalid indentation, got ' + indents + ' instead of ' + (lastIndents + 1) + " at " + context(str))
		            else if (indents < lastIndents) {
		              input = token[1].input
		              token = ['dedent']
		              token.input = input
		              while (--lastIndents > 0)
		                stack.push(token)
		            }
					break;
		        }
		        break
		      }
		    if (!ignore)
		      if (token)
		        stack.push(token),
		        token = null
		      else 
		        throw new SyntaxError(context(str))
		    ignore = false
		  }
		  return stack
		}
		

	}
}

/**
 * Simple data structure for grammar tokens.
 */
internal class GrammarToken
{
	private var _id:String;
	private var _regex:RegExp;
	
	public function GrammarToken(id:String, regex:RegExp)
	{
		_id = id;
		_regex = regex;
	}
	
	public function get id():String
	{
		return _id;
	}
	
	public function get regex():RegExp
	{
		return _regex;
	}
}