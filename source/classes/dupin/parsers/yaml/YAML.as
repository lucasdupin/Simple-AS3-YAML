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
		  ['indent', /^\n( *)/],
		  ['space', /^ +/],
		  ['true', /^(enabled|true|yes|on)/],
		  ['false', /^(disabled|false|no|off)/],
		  ['string', /^["|'](.*?)["|']/], //' Duh, syntax highligthing
		  ['float', /^(\d+\.\d+)/],
		  ['int', /^(\d+)/],
		  ['id', /^([\w ]+)/],
		  ['doc', /^---/],
		  [',', /^,/],
		  ['{', /^\{/],
		  ['}', /^\}/],
		  ['[', /^\[/],
		  [']', /^\]/],
		  ['-', /^\-/],
		  [':', /^[:]/],
		  ['string', /^(.*)/],
		]
		protected var tokens:Array;
		

		public function YAML(tokens:String)
		{
			this.tokens = tokenize(tokens);
		}

		public static function decode(str:String):*
		{
			return new YAML(str).parse();
		}
		
		private function context(str:*):String {
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
		 * @api private
		 */
		private function advanceValue():* {
		  return this.advance()[1][1]
		}
		
		/**
		 * Accept _type_ and advance or do nothing.
		 *
		 * @param  {string} type
		 * @return {bool}
		 * @api private
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
		 * @api private
		 */
		protected function expect(type:String, msg:String):void {
		  if (accept(type)) return;
		
		  throw new Error(msg + (this.peek() ? ', ' + context(this.peek()[1].input) : ''));
		}

		/**
		 * Return the next token type.
		 *
		 * @return {string}
		 * @api private
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
		 * | float
		 * | int
		 * | true
		 * | false
		 */

		protected function parse():* {
		  switch (this.peek()[0]) {
		    case 'doc':
		      return this.parseDoc()
		    case '-':
		      return this.parseList()
		    case '{':
		      return this.parseInlineHash()
		    case '[':
		      return this.parseInlineList()
		    case 'id':
		      return this.parseHash()
		    case 'string':
		      return this.advanceValue()
		    case 'float':
		      return parseFloat(this.advanceValue())
		    case 'int':
		      return parseInt(this.advanceValue())
		    case 'true':
		      return true
		    case 'false':
		      return false
		  }
		}

		/**
		 * '---'? indent expr dedent
		 */

		protected function parseDoc():* {
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

		protected function parseHash():Object {
		  var id:*, hash:Object = {}
		  while (this.peekType('id') && (id = this.advanceValue())) {
		    this.expect(':', 'expected semi-colon after id')
		    this.ignoreSpace()
		    if (this.accept('indent'))
		      hash[id] = this.parse(),
		      this.expect('dedent', 'hash not properly dedented')
		    else
		      hash[id] = this.parse()
		    this.ignoreSpace()
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
		 *  ( '-' - expr -
		 *  | '-' - indent expr dedent
		 *  )+
		 */

		protected function parseList():Array {
		  var list:Array = [];
		  while (this.accept('-')) {
		    this.ignoreSpace();
		    if (this.accept('indent'))
		      list.push(this.parse()),
		      this.expect('dedent', 'list item not properly dedented')
		    else
		      list.push(this.parse())
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
		    for (var i:int = 0, len:int = grammarTokens.length; i < len; ++i)
		      if ((captures = grammarTokens[i][1].exec(str)) != null) {
		        token = [grammarTokens[i][0], captures],
		        str = str.replace(grammarTokens[i][1], '')
		        switch (token[0]) {
		          case 'comment':
		            ignore = true
		            break
		          case 'indent':
		            lastIndents = indents
		            indents = token[1][1].length / 2
		            if (indents === lastIndents)
		              ignore = true
		            else if (indents > lastIndents + 1)
		              throw new SyntaxError('invalid indentation, got ' + indents + ' instead of ' + (lastIndents + 1) + " at " + context(str))
		            else if (indents < lastIndents) {
		              input = token[1].input
		              token = ['dedent']
		              token.input = input
		              while (--lastIndents > 0)
		                stack.push(token)
		            }
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