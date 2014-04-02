define 'polyfill-path/less-converters', [
  'underscore'
  'jquery'
  'cs!polyfill-path/selector-visitor'
], (_, $, AbstractSelectorVisitor) ->

  PSEUDO_CLASSES = [
    'before'
    'after'
    'outside'
    'footnote-call'
    'footnote-marker'
  ]

  # Convert CSS selectors to a valid CSS class name
  slugify = (str) ->
    str = str.replace(/\ +/g, ' ')                      # Collapse multiple whitespaces
    str = str.replace(/[^A-Za-z0-9>\[\]\(\)\.]/g, '-')  # Replace invalid chars with dash
    str = str.replace(/[\[\]\(\)]/g, '_')               # Replace brackets with underscore
    str = str.replace(/-+/g, '-')                       # Collapse multiple dashes
    str = str.replace(/>/g, '-child-')                  # Replace '>' with '-child-'
    str = str.replace(/\./g, '-dot-')                   # Replace '.' with '-dot-'
    str = str.replace(/-+/g, '-')                       # Collapse multiple '-' to one
    str = str.replace(/^-|-$/g, '')                     # Remove leading and trailing '-'
    return str

  freshClassIdCounter = 0
  freshClass = (selectorStr) ->
    selectorStr = slugify(selectorStr)
    return "js-polyfill-autoclass-#{freshClassIdCounter++}-#{selectorStr}"

  class AutogenClass
    # selector: less.tree.Selector # Used for calculating the priority (ie 'p > * > em')
    # rules: [less.tree.Rule]
    constructor: (@selectorStr, @elements, @rules) ->


  class PseudoExpander extends AbstractSelectorVisitor

    # Generates elements of the form `<span class="js-polyfill-pseudo-before"></span>`
    PSEUDO_ELEMENT_NAME: 'span' # 'polyfillpseudo'

    # Used to test if a selector is recognized by the browser by calling `node.querySelector(...)`
    selectorTestNode = $('<span></span>')[0]

    constructor: (root, @set, @interestingSet, plugins) ->
      super(arguments...)

      @interestingRules = []
      for plugin in plugins
        for ruleName of plugin.rules or {}
          @interestingRules[ruleName] = true


    hasInterestingRules: (ruleSet) ->
      # Always return true if the meta-rule `*` is in the set
      return true if @interestingRules['*']
      for rule in ruleSet.rules
        return true if rule.name of @interestingRules


    operateOnElements: (frame, ruleSet, domSelector, pseudoSelector, originalSelector, selectorStr) ->
      if not pseudoSelector.elements.length
        # Simple selector; no pseudoSelectors

        # Test if the selector will work in a browser. If so, keep it. Otherwise, generate a new class for it.
        try
          selectorTestNode.querySelector(selectorStr)
          isBrowserSelector = true
        catch e
          isBrowserSelector = false

        if isBrowserSelector
          autoClass = new AutogenClass(selectorStr, originalSelector.elements, ruleSet.rules)
          @set.add(selectorStr, autoClass)
          @interestingSet.add(selectorStr, autoClass) if @hasInterestingRules(ruleSet)
        else
          className = freshClass(selectorStr)
          @getNodes(selectorStr).addClass("js-polyfill-autoclass #{className}")
          selectorStr = ".#{className}"

          @set.add(selectorStr, autoClass)
          @interestingSet.add(selectorStr, autoClass) if @hasInterestingRules(ruleSet)

      else

        $nodes = @getNodes(selectorStr)
        $context = $nodes
        for pseudoNode in pseudoSelector.elements
          pseudoName = pseudoNode.value.replace('::', ':')

          simpleExpand = (op, pseudoName) =>
            # See if the pseudo element exists.
            # If not, add it to the DOM
            cls         = "js-polyfill-pseudo-#{pseudoName}"
            $needsNew   = $context.not($context.has(" > .#{cls}, > .js-polyfill-pseudo-outside > .#{cls}"))
            $needsNew[op]("<#{@PSEUDO_ELEMENT_NAME} class='js-polyfill-pseudo #{cls}'></#{@PSEUDO_ELEMENT_NAME}>")
            # Update the context to be current pseudo element
            $context = $context.find("> .#{cls}, > .js-polyfill-pseudo-outside > .#{cls}")


          selectorStr += pseudoName # Append to `selectorStr` so the autogen class contains the pseudo elements

          switch pseudoName
            when ':before'          then simpleExpand('prepend', 'before')
            when ':after'           then simpleExpand('append',  'after')
            when ':footnote-marker' then simpleExpand('prepend', 'footnote-marker')
            when ':footnote-call'   then simpleExpand('append',  'footnote-call')

            when ':outside'
              op          = 'wrap'
              pseudoName  = 'outside'
              # See if the pseudo element exists.
              # If not, add it to the DOM
              cls         = "js-polyfill-pseudo-#{pseudoName}"
              $needsNew   = $context.not $context.filter (node) ->
                              $parent = $(node).parent()
                              return $parent.hasClass(cls)
              $needsNew[op]("<#{@PSEUDO_ELEMENT_NAME} class='js-polyfill-pseudo #{cls}'></#{@PSEUDO_ELEMENT_NAME}>")
              # Update the context to be current pseudo element
              $context = $context.parent()

            else

        if $context != $nodes
          newClassName = freshClass(selectorStr)
          $context.addClass("js-polyfill-autoclass #{newClassName}")

          autoClass = new AutogenClass(selectorStr, pseudoSelector.elements, ruleSet.rules, @hasInterestingRules(ruleSet))
          # Do this **after** we create the AutogenClass so it squirrels away the _original_ selector for BASED_ON comment
          selectorStr = ".#{newClassName}"

          @set.add(selectorStr, autoClass)
          @interestingSet.add(selectorStr, autoClass) if @hasInterestingRules(ruleSet)


  return {
    PseudoExpander: PseudoExpander
  }
