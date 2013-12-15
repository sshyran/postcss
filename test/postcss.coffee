SourceMap = require('source-map')
postcss   = require('../lib/postcss')
Result    = require('../lib/result')
Root      = require('../lib/root')

describe 'postcss()', ->

  it 'creates processors list', ->
    postcss().should.eql { processors: [] }

  it 'saves processors list', ->
    a = -> 1
    b = -> 2
    postcss(a, b).should.eql { processors: [a, b] }

  it 'processes CSS', ->
    processor = postcss (css) ->
      css.eachRule (rule) ->
        return unless rule.selector.match(/::(before|after)/)
        unless rule.some( (i) -> i.prop == 'content' )
          rule.prepend(prop: 'content', value: '""')

    processor.process('a::before{}').css.should.eql('a::before{content: ""}')

  it 'allows to replace Root', ->
    processor = postcss -> new Root()
    processor.process('a {}').css.should.eql('')

  describe 'parse()', ->

    it 'parses CSS', ->
      css = postcss.parse('a { }')
      css.should.be.an.instanceof(Root)

    it 'throws with file name', ->
      error = null
      try
        postcss.parse('a {', from: 'A')
      catch e
        error = e

      e.file.should.eql    'A'
      e.message.should.eql 'Can\'t parse CSS: Unclosed block at line 1:1 in A'

describe 'PostCSS', ->

  describe 'use()', ->

    it 'adds new processors', ->
      a = -> 1
      processor = postcss()
      processor.use(a)
      processor.should.eql { processors: [a] }

    it 'returns itself', ->
      a = ->
      b = ->
      postcss().use(a).use(b).should.eql { processors: [a, b] }

  describe 'process()', ->

    it 'returns Result object', ->
      result = postcss().process('a{}')
      result.should.be.an.instanceOf(Result)
      result.css.should.eql        'a{}'
      result.toString().should.eql 'a{}'

    it 'calls all processors', ->
      calls = ''
      a = -> calls += 'a'
      b = -> calls += 'b'

      postcss(a, b).process('')
      calls.should.eql 'ab'

    it 'parses, convert and stringify CSS', ->
      a = (css) -> css.should.be.an.instanceof(Root)
      postcss(a).process('a {}').css.should.have.type('string')

    it 'adds map field only on request', ->
      postcss().process('a {}').should.not.have.property('map')

    it 'generate right source map', ->
      css       = "a {\n  color: black;\n  }"
      processor = postcss (css) ->
        css.eachRule (rule) ->
          rule.selector = 'strong'
        css.eachDecl (decl) ->
          changed = decl.clone(prop: 'background')
          decl.parent.prepend(changed)

      map = processor.process(css, map: true, from: 'a.css', to: 'b.css').map
      map = new SourceMap.SourceMapConsumer(JSON.parse(map))

      map.file.should.eql('b.css')

      map.originalPositionFor(line: 1, column: 0).should.eql
        source: 'a.css'
        line:   1
        column: 0
        name:   null
      map.originalPositionFor(line: 2, column: 2).should.eql
        source: 'a.css'
        line:   2
        column: 2
        name:   null
      map.originalPositionFor(line: 3, column: 2).should.eql
        source: 'a.css'
        line:   2
        column: 2
        name:   null
