
module.exports = class Slugifiable

  {dash, daisy} = require 'bongo'

  slugify =(str)->
    slug = str
      .toLowerCase()                # change everything to lowercase
      .replace(/^\s+|\s+$/g, "")    # trim leading and trailing spaces
      .replace(/[_|\s]+/g, "-")     # change all spaces and underscores to a hyphen
      .replace(/[^a-z0-9-]+/g, "")  # remove all non-alphanumeric characters except the hyphen
      .replace(/[-]+/g, "-")        # replace multiple instances of the hyphen with a single instance
      .replace(/^-+|-+$/g, "")      # trim leading and trailing hyphens
      .substr 0, 256                # limit these to 256-chars (pre-suffix), for sanity

  generateUniqueSlug =(konstructor, slug, i, template, callback)->
    [callback, template] = [template, callback]  unless callback
    template or= '#{slug}'
    JName = require '../models/name'
    nameRE = RegExp "^#{template.replace '#\{slug\}', slug}(-\\d+)?$"
    selector = {name:nameRE}
    JName.someData selector, {name:1}, {sort:name:-1}, (err, cursor)->
      if err then callback err
      else cursor.toArray (err, names)->
        if err then callback err
        else
          nextCount = names
            .map((nm)->
              [d] = (/\d+$/.exec nm) ? [0]
              [+d, nm])
            .sort ([a], [b])->
              a > b
            .pop()
            .shift()

          nextCount =\
            if isNaN nextCount then ''
            else nextCount + 1

          nextName = "#{slug}#{nextCount}"
          nextNameFull = template.replace '#{slug}', nextName
          # selector = {name: nextName, constructorName, usedAsPath: 'slug'}
          JName.claim nextNameFull, konstructor, 'slug', (err, nameDoc)->
            if err?.code is 11000
              console.log 'doh!', nextNameFull
              # we lost the race; try again
              generateUniqueSlug konstructor, slug, 0, template, callback
            else if err
              callback err
            else
              callback null, nextName
    
  @updateAllSlugsResourceIntensively = (options, callback)->
    [callback, options] = [options, callback] unless callback
    options ?= {}
    selector = if options.force then {} else {slug_: $exists: no}
    subclasses = @encapsulatedSubclasses ? [@]
    JName = require '../models/name'
    JName.someData {},{name:1,_id:1,constructorName:1},{},(err,names)->
      console.log "namesArr in"
      names.toArray (err,namesArr)->
        contentTypeQueue = subclasses.map (subclass)->->
          console.log "2"  
          subclass.someData {},{title:1,_id:1},{limit:1000},(err,cursor)->
            console.log "3"
            if err
              callback err
            else
              cursor.toArray (err,arr)->
                if err
                  callback err
                else
                  a.contructorName = subclass.name for a in arr
                  console.log "4"
                  console.log "arr ->",arr,"namesArr -> ",namesArr
                  callback null #,arr,namesArr
          
        dash contentTypeQueue, callback
      # subclass.cursor selector, options, (err, cursor)->
      #   if err then contentTypeQueue.next err
      #   else
      #     postQueue = []
      #     cursor.each (err, post)->
      #       if err then postQueue.next err
      #       else if post?
      #         postQueue.push -> post.updateSlug (err, slug)->
      #           callback null, slug
      #           postQueue.next()
      #       else
      #         daisy postQueue, -> contentTypeQueue.fin()
        

  @updateAllSlugs = (options, callback)->
    [callback, options] = [options, callback] unless callback
    options ?= {}
    selector = if options.force then {} else {slug_: $exists: no}
    subclasses = @encapsulatedSubclasses ? [@]
    contentTypeQueue = subclasses.map (subclass)->->
      subclass.cursor selector, options, (err, cursor)->
        if err then console.error err #contentTypeQueue.next err
        else
          postQueue = []
          cursor.each (err, post)->
            if err then console.error err#postQueue.next err
            else if post?
              postQueue.push ->
                post.updateSlug (err, slug)->
                  callback null, slug
                  postQueue.next()
            else
              console.log postQueue.length
              daisy postQueue, -> contentTypeQueue.fin()
    dash contentTypeQueue, callback

  updateSlug:(callback)->
    console.log 'body', @body
    @createSlug (err, slug)=>
      if err then callback err
      else @update $set:{slug, slug_:slug}, (err)->
        callback err, unless err then slug

  createSlug:(callback)->
    {constructor} = this
    {slugTemplate, slugifyFrom} = constructor
    slug = slugify @[slugifyFrom]
    generateUniqueSlug constructor, slug, 0, slugTemplate, callback
