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
		
		// --- Lexer

		/**
		 * YAML grammar tokens.
		 */

		protected const grammarTokens:Array = [
		  ['comment', /^#[^\n]*/],
		  ['indent', /^\s*\n(\s*)/],
		  ['space', /^\s+/],
		  ['true', /^(enabled|true|yes|on)/],
		  ['false', /^(disabled|false|no|off)/],
		  ['string', /^["|'](.*?)["|']/], //' Duh, syntax highligthing
		  ['multilineString', /^\|[^\n]*/],
		  ['float', /^(\d+\.\d+)/],
		  ['int', /^(\d+)/],
		  ['id', /^([\w ]+)\s*:/],
		  ['doc', /^---/],
		  [',', /^,/],
		  ['{', /^\{/],
		  ['}', /^\}/],
		  ['[', /^\[/],
		  [']', /^\]/],
      //['-', /^\-/],
		  ['-', /^(\- )/],
		  [':', /^[:]/],
		  ['string', /^(.*)/],
		]
		protected var tokens:Array;
		
		/**
		 * Receives a string and breaks it into tokens
		 * @constructor
		 */
		public function YAML(tokens:String)
		{
			this.tokens = tokenize(tokens);
		}
		
		/**
		 * Transform tokens into objects
		 */
		public static function decode(str:String):*
		{
			return new YAML(str).parse();
		}
		
		private function context(str:*):String {
		  if (!(str is String)) return '';
		  str = str
		    .slice(0, 25)
		    .replace(/\n/g, '\\n')
		    .replace(/"/g, '\\\"');
		  return 'near "' + str + '"';
		}
		
		/**
		 * Look-ahead a single token.
		 *
		 * @return {array}
		 * @api public
		 */
		protected function peek():Array {
		  return this.tokens[0];
		}

		/**
		 * Advance by a single token.
		 *
		 * @return {array}
		 * @api public
		 */
		protected function advance():Array {
		  return this.tokens.shift();
		}
		
		/**
		 * Advance and return the token's value.
		 *
		 * @return {mixed}
		 */
		protected function advanceValue():* {
		  return this.advance()[1][1];
		}
		
		/**
		 * Accept _type_ and advance or do nothing.
		 *
		 * @param  {string} type
		 * @return {bool}
		 */
		protected function accept(type:String):* {
		  if (this.peekType(type))
		    return this.advance();
		
		  return false;
		}

		/**
		 * Expect _type_ or throw an error _msg_.
		 *
		 * @param  {string} type
		 * @param  {string} msg
		 */
		protected function expect(type:String, msg:String):void {
			if (accept(type)) return;
				
			var near:String = '';
			if(this.peek())
				near = peek()[1].hasOwnProperty('input') ? this.peek()[1].input : this.peek()[1];
		
			throw new Error(msg +  ', ' +  near);
		}

		/**
		 * Return the next token type.
		 *
		 * @return {string}
		 */
		protected function peekType(val:String):Boolean {
		  return this.tokens[0] &&
		         this.tokens[0][0] === val;
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

		protected function parse():* {
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

		protected function parseDoc():* {
		  this.accept('doc');
		  this.expect('indent', 'expected indent after document');
		  var val:* = this.parse();
		  if(!this.peekType('eof')) this.expect('dedent', 'document not properly dedented');
		  return val;
		}

		/**
		 *  ( id ':' - expr -
		 *  | id ':' - indent expr dedent
		 *  )+
		 */

		protected function parseHash():Object {
		  var id:*, hash:Object = {}
		  while (this.peekType('id') && (id = this.advanceValue())) {
		    this.expect(':', 'expected semi-colon after id')
		    this.ignoreSpace()
		    if (this.accept('indent'))
		    {
          //trace("YAML::parseHash() INDENT", id, this.tokens[0]);
		      hash[id] = this.parse();
    		  if(!this.peekType('eof')) this.expect('dedent', 'hash not properly dedented')
		    } 
		    else {
          //trace("YAML::parseHash() ELSE", id, this.tokens[0]);
          hash[id] = this.parse();
          
			  }
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
		
		
		protected function parseMultilineString():String {
			var result:String="", val:String="";
			this.advanceValue(); //ignore first | (pipe)
			//Ignore space and expect indent
			this.ignoreSpace();
			this.expect('indent', "multiline string not properly indented");
			while(!this.peekType('dedent') && (val = this.advanceValue())){
        //trace("YAML::parseMultilineString()", tokens[0]);
				result += val + "\n";
				ignoreSpace();
			}
			this.expect('dedent', "multiline string not properly dedented");
			result = result.substr(0, result.length-1);
			
			return result;
		}

		/**
		 *  ( '-' - expr -
		 *  | '-' - indent expr dedent
		 *  )+
		 */

		protected function parseList():Array {
		  var list:Array = [];
		  while (this.accept('-')) {
		    this.ignoreSpace();
		    if (this.accept('indent')) {
          //trace("YAML::parseList() IF");
		      list.push(this.parse());
		      if(!this.peekType('eof'))  this.expect('dedent', 'list item not properly dedented');
		    } else {
          //trace("YAML::parseList() ELSE");
		      list.push(this.parse())
		    }
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
		 */

		protected function tokenize(str:String):Array {
		  var token:Array, captures:Array, ignore:Boolean, input:*,
		      indents:int = 0, lastIndents:int = 0,
		      stack:Array = [], inList:Boolean = false;
		
		  while (str.length) {
		    for (var i:int = 0, len:int = grammarTokens.length; i < len; ++i)
		      if ((captures = grammarTokens[i][1].exec(str)) != null) {
		        token = [grammarTokens[i][0], captures],
						str = str.replace(grammarTokens[i][1], '');
						
						//Modified id regexp, so it will consider ':', avoiding confusion with strings
						if(grammarTokens[i][0] == 'id')
		        	str = ':' + str;
		
				
				switch (token[0]) {
		          case 'comment':
		            ignore = true
		            break;
		          case '-':
                //trace("YAML::tokenize() forcing list indent");
		            indents = indents + 1;
		            stack.push(token);
		            token = ['indent','  '];
		            break;
		          case 'indent':
		            lastIndents = indents
		            indents = token[1][1].length / 2
                //trace("YAML::tokenize() INDENT --- ", indents);
		            if (indents === lastIndents)
		              ignore = true//, trace("IGNORE")
		            else if (indents > lastIndents + 1)
		              throw new SyntaxError('invalid indentation, got ' + indents + ' instead of ' + (lastIndents + 1) + " at " + context(str))
		            else if (indents < lastIndents) {
                  //trace("YAML::tokenize()", "DEDENT");
		              input = token[1].input;
		              token = ['dedent',''];
		              token.input = input;
		              while (--lastIndents > indents)
		                stack.push(token);
		            }
					break;
		        }
		        break
		      }
		
			if (!ignore)
				if (token) {
					stack.push(token);
					token = null;
				} else {
					throw new SyntaxError(context(str))
				}
		    ignore = false
		  }
		  //Add EOF token
		  stack.push(['eof', ''])
      //traceTokens(stack);
		  return stack;
		}
		
		/**
		 * Temporary debugging method
		 * @param stack Array 
		 */
		public function traceTokens(stack:Array):void
		{
		  for each (var tkn:Object in stack)
		  {
        var valueStr:String = (tkn[1] is Array)?""+tkn[1][0]:"";
		    trace("[ "+tkn[0]+" ]  "+valueStr);
		  }
		}
		

	}
}