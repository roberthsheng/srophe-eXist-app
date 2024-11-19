xquery version "3.1";        
(:~  
 : Builds HTML search forms and HTMl search results Srophe Collections and sub-collections   
 :) 
module namespace search="http://srophe.org/srophe/search";

(:eXist templating module:)
import module namespace templates="http://exist-db.org/xquery/html-templating";

(: Import KWIC module:)
import module namespace kwic="http://exist-db.org/xquery/kwic";

(: Import Srophe application modules. :)
import module namespace config="http://srophe.org/srophe/config" at "../config.xqm";
import module namespace bibls="http://srophe.org/srophe/bibls" at "bibl-search.xqm";
import module namespace data="http://srophe.org/srophe/data" at "../lib/data.xqm";
import module namespace global="http://srophe.org/srophe/global" at "../lib/global.xqm";
import module namespace facet="http://expath.org/ns/facet" at "facet.xqm";
import module namespace sf="http://srophe.org/srophe/facets" at "../lib/facets.xql";
import module namespace page="http://srophe.org/srophe/page" at "../lib/paging.xqm";
import module namespace slider = "http://srophe.org/srophe/slider" at "../lib/date-slider.xqm";
import module namespace tei2html="http://srophe.org/srophe/tei2html" at "../content-negotiation/tei2html.xqm";

declare namespace tei="http://www.tei-c.org/ns/1.0";

(: Global Variables:)
declare variable $search:start {
    if(request:get-parameter('start', 1)[1] castable as xs:integer) then 
        xs:integer(request:get-parameter('start', 1)[1]) 
    else 1};
declare variable $search:perpage {
    if(request:get-parameter('perpage', 25)[1] castable as xs:integer) then 
        xs:integer(request:get-parameter('perpage', 25)[1]) 
    else 25
    };

(:~
 : Builds search result, saves to model("hits") for use in HTML display
:)

(:~
 : Search results stored in map for use by other HTML display functions
 : Updated for Architectura Sinica to display full list if no search terms
:)
declare %templates:wrap function search:search-data($node as node(), $model as map(*), $collection as xs:string?, $sort-element as xs:string*){
    let $sort := $sort-element[1]
    let $queryExpr := search:query-string($collection)     
    let $hits := if($queryExpr != '') then 
                     data:search($collection, $queryExpr,$sort)
                 else data:search($collection, '',$sort)
    let $sites := for $h in $hits[.//tei:place[@type='site']]
                  let $s := ft:field($h, "title")[1]                
                  order by $s[1] collation 'http://www.w3.org/2013/collation/UCA'
                  return $h 
    let $allSites := collection('/db/apps/tcadrt-data/data/places/sites')//tei:TEI
    return  
        map {
                "hits" : $hits,
                "sites" : $sites,
                "allSites" : $allSites,
                "query" : $queryExpr
        } 
};

(:~ 
 : Builds results output
:)
declare 
    %templates:default("start", 1)
function search:show-hits($node as node()*, $model as map(*), $collection as xs:string?, $kwic as xs:string?) {
<div class="indent" id="search-results" xmlns="http://www.w3.org/1999/xhtml">
    {
            if($collection = 'places') then 
                if(count($model("sites")) = 0 and count($model("hits")) != 0) then
                    for $hit at $p in subsequence($model("hits"), $search:start, $search:perpage)
                    let $idno := replace($hit/descendant::tei:idno[1],'/tei','')
                    let $title := tei2html:tei2html($hit/descendant::tei:title[1])
                    let $siteIdno := $hit/descendant::tei:relation[@ref="schema:containedInPlace"]/@passive
                    let $site := $model("allSites")[descendant::tei:idno[.= $siteIdno]][1]
                    let $siteTitle := $hit[1]/descendant::tei:title[1]
                    group by $facet-grp-p := $siteIdno[1]
                    order by $siteTitle[1]
                    return 
                        <div class="indent" xmlns="http://www.w3.org/1999/xhtml" style="margin-bottom:1em;">
                            <a class="togglelink text-info" 
                                    data-toggle="collapse" data-target="#show{$facet-grp-p}" 
                                    href="#show{$facet-grp-p}" data-text-swap=" + "> - </a>&#160; 
                                    <a href="{replace($idno[1],$config:base-uri,$config:nav-base)}">{tei2html:tei2html($siteTitle[1])}</a> (contains {count($hit)} artifact(s))
                                    <div class="indent collapse in" style="background-color:#F7F7F9;" id="show{$facet-grp-p}">{
                                        for $p in $hit
                                        let $id := replace($p/descendant::tei:idno[1],'/tei','')
                                        return 
                                            <div class="indent" style="border-bottom:1px dotted #eee; padding:1em">{tei2html:summary-view(root($p), '', $id)}</div>
                                    }</div>
                        </div>   
                else 
                    let $hits := $model("sites") 
                    for $hit at $p in subsequence($hits, $search:start, $search:perpage)
                    let $title := $hit/descendant::tei:title[1]
                    let $idno := replace($hit/descendant::tei:idno[1],'/tei','') 
                    let $children := 
                       (:$model("hits")//tei:TEI[.//tei:relation[@passive = $idno][@ref="schema:containedInPlace"]]:)
                       collection($config:data-root)//tei:TEI[.//tei:relation[@ref="schema:containedInPlace"][@passive = $idno]]
                    return 
                        <div class="indent" xmlns="http://www.w3.org/1999/xhtml" style="margin-bottom:1em;">
                            <a class="togglelink text-info" data-toggle="collapse" data-target="#show{$idno}" href="#show{$idno}" data-text-swap=" + "> - </a>&#160; 
                            <a href="{replace($idno,$config:base-uri,$config:nav-base)}">{tei2html:tei2html($title)}</a> (contains {count($children)} artifact(s))
                            <div class="indent collapse in" style="background-color:#F7F7F9;" id="show{$idno}">{
                                for $p in $children
                                let $id := replace($p/descendant::tei:idno[1],'/tei','')
                                return 
                                    <div class="indent" style="border-bottom:1px dotted #eee; padding:1em">{tei2html:summary-view($p, '', $id)}</div>
                            }</div>
                        </div>                       
            else 
                let $hits := $model("hits")
                for $hit at $p in subsequence($hits, $search:start, $search:perpage)
                let $id := replace($hit/descendant::tei:idno[1],'/tei','')
                return 
                <div class="row record" xmlns="http://www.w3.org/1999/xhtml">
                     <div class="col-md-1" style="margin-right:-1em; padding-top:.25em;">        
                         <span class="badge" style="margin-right:1em;">{$search:start + $p - 1}</span> 
                     </div>
                     <div class="col-md-11" style="margin-right:-1em; padding-top:.25em;">
                         {tei2html:summary-view(root($hit), '', $id)}
                     </div>
                 </div>
       } 
</div>
};

(:~ 
 : Builds results output for the DSA page
:)
declare 
    %templates:default("start", 1)
function search:dsa-show-hits($node as node()*, $model as map(*), $collection as xs:string?, $kwic as xs:string?) {
<div class="indent" id="search-results" xmlns="http://www.w3.org/1999/xhtml">
    {
            if($collection = 'places') then 
                if(count($model("sites")) = 0 and count($model("hits")) != 0) then
                    for $hit at $p in subsequence($model("hits"), $search:start, $search:perpage)
                    let $idno := replace($hit/descendant::tei:idno[1],'/tei','')
                    let $title := tei2html:tei2html($hit/descendant::tei:title[1])
                    let $siteIdno := $hit/descendant::tei:relation[@ref="schema:containedInPlace"]/@passive
                    let $site := $model("allSites")[descendant::tei:idno[.= $siteIdno]][1]
                    let $siteTitle := $hit[1]/descendant::tei:title[1]
                    group by $facet-grp-p := $siteIdno[1]
                    order by $siteTitle[1]

                    return 
                    <div class="indent" xmlns="http://www.w3.org/1999/xhtml" style="margin-bottom:1em; padding: 10px; border: 1px solid #ccc; background-color: #ffffff;">
                        <a href="{replace($idno[1], $config:base-uri, $config:nav-base)}" 
                           style="font-family: Arial, sans-serif; color: #000000; font-size: 18px;">
                          {tei2html:tei2html($siteTitle[1])}
                        </a> (contains {count($hit)} artifact(s))
                        <div class="indent collapse in" style="background-color:#FFFFFF;" id="show{$facet-grp-p}">{
                            for $p in $hit
                            let $id := replace($p/descendant::tei:idno[1],'/tei','')
                            return 
                                <div class="indent" style="border-bottom:1px dotted #eee; padding:0.3em; color: #000000">{tei2html:dsa-summary-view(root($p), '', $id)}</div>
                        }</div>
                    </div>   
                else 
                    let $hits := $model("sites") 
                    for $hit at $p in subsequence($hits, $search:start, $search:perpage)
                    let $title := $hit/descendant::tei:title[1]
                    let $idno := replace($hit/descendant::tei:idno[1],'/tei','') 
                    let $children := 
                       (:$model("hits")//tei:TEI[.//tei:relation[@passive = $idno][@ref="schema:containedInPlace"]]:)
                       collection($config:data-root)//tei:TEI[.//tei:relation[@ref="schema:containedInPlace"][@passive = $idno]]
            
                    return 
                    <div class="indent" xmlns="http://www.w3.org/1999/xhtml" style="margin-bottom:1em; padding: 10px; border: 1px solid #ccc; background-color: #ffffff;">           
                        <a href="{replace($idno, $config:base-uri, $config:nav-base)}" 
                           style="font-family: Arial, sans-serif; color: #000000; font-size: 18px;">
                          {tei2html:tei2html($title)}
                        </a> (contains {count($children)} artifact(s))
                        <div class="indent collapse in" style="background-color:#FFFFFF;" id="show{$idno}">{
                            for $p in $children
                            let $id := replace($p/descendant::tei:idno[1],'/tei','')
                            return 
                                <div class="indent" style="border-bottom:1px dotted #eee; padding:0.3em; color: #000000">{tei2html:dsa-summary-view($p, '', $id)}</div>
                        }</div>
                    </div>                       
            else 
                let $hits := $model("hits")
                for $hit at $p in subsequence($hits, $search:start, $search:perpage)
                let $id := replace($hit/descendant::tei:idno[1],'/tei','')
                return 
                <div class="row record" xmlns="http://www.w3.org/1999/xhtml">
                     <div class="col-md-1" style="margin-right:-1em; padding-top:.25em;">        
                         <span class="badge" style="margin-right:1em;">{$search:start + $p - 1}</span> 
                     </div>
                     <div class="col-md-11" style="margin-right:-1em; padding-top:.25em;">
                         {tei2html:dsa-summary-view(root($hit), '', $id)}
                     </div>
                 </div>
       } 
</div>
};


(: Architectura Sinica functions :)
(:
 : TCADRT - display architectural features select lists for research-tool.html
 facet-architecturalFeature=
:)
declare %templates:wrap function search:architectural-features($node as node()*, $model as map(*)){ 
    <div class="row">{
        let $features := collection($config:data-root || '/keywords')/tei:TEI[descendant::tei:entryFree[@type='architectural-feature' or @type='architectural feature']]
        for $feature in $features
        let $type := string($feature/descendant::tei:relation[@ref = 'skos:broadMatch'][1]/@passive)
        group by $group-type := $type
        return  
            <div class="col-md-6">
                <h4 class="indent">{string($group-type)}</h4>
                {
                    for $f in $feature
                    let $title-en := $f/descendant::tei:entryFree/tei:term[@xml:lang='zh-latn-pinyin'][not(@type='alternate')][1]/text()
                    let $title-zh := $f/descendant::tei:entryFree/tei:term[@xml:lang='zh-Hant'][1]/text()
                    let $title := concat($title-en, ' ', $title-zh)
                    let $id := replace($f/descendant::tei:idno[1],'/tei','')
                    order by $title-en ascending collation 'http://www.w3.org/2013/collation/UCA'
                    return 
                        <div class="form-group row">
                            <div class="col-sm-4 col-md-3" style="text-align:right;">
                                  { if($f/descendant::tei:entryFree/@sub-type='numeric') then
                                    <select name="{concat('feature-num:',$id)}" class="inline">
                                      <option value="">No.</option>
                                      <option value="1">1</option>
                                      <option value="2">2</option>
                                      <option value="3">3</option>
                                      <option value="4">4</option>
                                      <option value="5">5</option>
                                      <option value="6">6</option>
                                      <option value="7">7</option>
                                      <option value="8">8</option>
                                      <option value="9">9</option>
                                      <option value="10">10</option>
                                    </select>
                                    else ()}
                            </div>    
                            <div class="checkbox col-sm-8 col-md-9" style="text-align:left;margin:0;padding:0">
                                <label><input type="checkbox" value="true" name="{concat('feature:',$id)}"/>{$title}</label>
                            </div>
                        </div>
                    }
           </div>                    
    }</div>
};

(: TCADRT terms:)
declare function search:terms(){
    if(request:get-parameter('term', '')) then 
        data:element-search('term',request:get-parameter('term', '')) 
    else '' 
};

(: TCADRT architectural feature search functions :)
declare function search:features(){
    string-join(
    for $feature in request:get-parameter-names()[starts-with(., 'feature:' )]
    let $name := substring-after($feature,'feature:')
    let $number := 
        for $feature-number in request:get-parameter-names()[starts-with(., 'feature-num:' )][substring-after(.,'feature-num:') = $name]
        let $num-value := request:get-parameter($feature-number, '')
        return
            if($num-value != '' and $num-value != '0') then 
               concat("[descendant::tei:num[. = '",$num-value,"']]")
           else ()
    return 
        if(request:get-parameter($feature, '') = 'true') then 
            concat("[descendant::tei:relation[@ana='architectural-feature'][@passive = '",$name,"']",$number,"]")
        else ())      
};

(:~   
 : Builds general search string from main Architecture Sinica page and search api.
:)
declare function search:query-string($collection as xs:string?) as xs:string?{
let $search-config := concat($config:app-root, '/', string(config:collection-vars($collection)/@app-root),'/','search-config.xml')
return
    if($collection != '') then 
        if($collection = 'places') then  
            concat(data:build-collection-path($collection),
            slider:date-filter(()),
            data:keyword-search(),
            data:element-search('placeName',request:get-parameter('placeName', '')),
            data:element-search('title',request:get-parameter('title', '')),
            data:element-search('bibl',request:get-parameter('bibl', '')),
            data:uri(),
            search:terms(),
            data:element-search('term',request:get-parameter('term', '')),
            search:features()
          )
        else if($collection = 'keywords') then 
            concat(data:build-collection-path($collection),
            slider:date-filter(()),
            data:keyword-search(),
            data:element-search('title',request:get-parameter('title', '')),
            data:element-search('bibl',request:get-parameter('bibl', '')),
            data:uri(),
            search:terms(),
            data:element-search('term',request:get-parameter('term', '')),
            search:features())
        else if($collection = 'bibl') then bibls:query-string()            
        else 
            concat(data:build-collection-path($collection),
            slider:date-filter(()),
            data:keyword-search(),
            data:element-search('placeName',request:get-parameter('placeName', '')),
            data:element-search('title',request:get-parameter('title', '')),
            data:element-search('bibl',request:get-parameter('bibl', '')),
            data:uri(),
            search:terms(),
            search:features()
          )
    else concat(data:build-collection-path($collection),
        slider:date-filter(()),
        data:keyword-search(),
        data:element-search('placeName',request:get-parameter('placeName', '')),
        data:element-search('title',request:get-parameter('title', '')),
        data:element-search('bibl',request:get-parameter('bibl', '')),
        data:uri(),
        search:features()
        )
};

