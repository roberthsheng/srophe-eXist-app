xquery version "3.0";

module namespace app="http://syriaca.org/templates";

import module namespace templates="http://exist-db.org/xquery/templates" ;
import module namespace teiDocs="http://syriaca.org/teiDocs" at "teiDocs/teiDocs.xqm";
import module namespace global="http://syriaca.org/global" at "lib/global.xqm";
import module namespace rel="http://syriaca.org/related" at "lib/get-related.xqm";

declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace xlink = "http://www.w3.org/1999/xlink";

(:~             
 : Syriaca.org URI for retrieving TEI records 
:)
declare variable $app:id {request:get-parameter('id', '')}; 

(:~ 
 : Traverse main nav and "fix" links based on values in config.xml 
:)
declare
    %templates:wrap
function app:fix-links($node as node(), $model as map(*)) {
    templates:process(global:fix-links($node/node()), $model)
};

declare function app:rel-links($node as node(), $model as map(*)) {
    if($app:id) then 
    (
    (: some rdf examples
    <link type="application/rdf+xml" href="/entity/work/data/341546529.rdf" rel="alternate"/>
    <link type="text/turtle" href="/entity/work/data/341546529.ttl" rel="alternate"/>
    <link type="text/plain" href="/entity/work/data/341546529.nt" rel="alternate"/>
    <link type="application/json+ld" href="/entity/work/data/341546529.jsonld" rel="alternate"/>
    <link type="text/html" href="/entity/work/data/341546529.html" rel="alternate"/>
    :)
    <link xmlns="http://www.w3.org/1999/xhtml" type="text/html" href="{$app:id}.html" rel="alternate"/>,
    <link xmlns="http://www.w3.org/1999/xhtml" type="text/xml" href="{$app:id}/tei" rel="alternate"/>,
    <link xmlns="http://www.w3.org/1999/xhtml" type="application/atom+xml" href="{$app:id}/atom" rel="alternate"/>
    )
    else ()
};

declare
    %templates:wrap
function app:dc-header($node as node(), $model as map(*)) {
    if($app:id) then 
    (
    <link type="text/html" href="{$app:id}.html" rel="alternate"/>,
    <link type="text/xml" href="{$app:id}/tei" rel="alternate"/>,
    <link type="application/atom+xml" href="{$app:id}/atom" rel="alternate"/>
    )
    else ()
};

(:~ 
 : Enables shared content with template expansion.  
 : @param $node
 : @param $model
 : @param $path path to html content file, relative to app root. 
:)
declare function app:shared-content($node as node(), $model as map(*), $path as xs:string){
    let $links := doc($global:app-root || $path)
    return templates:process(global:fix-links($links/node()), $model)
};

(:~ 
 : Adds google analytics from config.xml
 : @param $node
 : @param $model
 : @param $path path to html content file, relative to app root. 
:)
declare  
    %templates:wrap 
function app:google-analytics($node as node(), $model as map(*)){
   $global:get-config//google_analytics/text() 
};

(:~
 : Dashboard function outputs collection statistics. 
 : $data collection data
 : $collection-title title of sub-module/collection
 : $data-dir 
:)
declare %templates:wrap function app:dashboard($node as node(), $model as map(*), $collection-title, $data-dir){
    let $data := collection(concat($global:data-root,'/',$data-dir,'/tei'))
    let $data-type := if($data-dir) then $data-dir else 'data'
    let $rec-num := count($data)
    let $contributors := for $contrib in distinct-values(for $contributors in $data//tei:respStmt/tei:name return $contributors) return <li>{$contrib}</li>
    let $contrib-num := count($contributors)
    let $data-points := count($data//tei:body/descendant::text())
    return
    <div class="panel-group" id="accordion" role="tablist" aria-multiselectable="true">
        <div class="panel panel-default">
            <div class="panel-heading" role="tab" id="dashboardOne">
                <h4 class="panel-title">
                    <a role="button" data-toggle="collapse" data-parent="#accordion" href="#collapseOne" aria-expanded="true" aria-controls="collapseOne">
                        <i class="glyphicon glyphicon-dashboard"></i> {concat(' ',$collection-title,' ')} Dashboard
                    </a>
                </h4>
            </div>
            <div id="collapseOne" class="panel-collapse collapse in" role="tabpanel" aria-labelledby="dashboardOne">
                <div class="panel-body dashboard">
                    <div class="row" style="padding:2em;">
                        <div class="col-md-4">
                            <div class="panel panel-primary">
                                <div class="panel-heading">
                                    <div class="row">
                                        <div class="col-xs-3"><i class="glyphicon glyphicon-file"></i></div>
                                        <div class="col-xs-9 text-right">
                                            <div class="huge">{$rec-num}</div><div>{$data-dir}</div>
                                        </div>
                                    </div>
                                </div>
                                <div class="collapse panel-body" id="recCount">
                                    <p>This number represents the count of {$data-dir} currently described in <i>{$collection-title}</i> as of {current-date()}.</p>
                                    <span><a href="browse.html"> See records <i class="glyphicon glyphicon-circle-arrow-right"></i></a></span>
                                </div>
                                <a role="button" 
                                    data-toggle="collapse" 
                                    href="#recCount" 
                                    aria-expanded="false" 
                                    aria-controls="recCount">
                                    <div class="panel-footer">
                                        <span class="pull-left">View Details</span>
                                        <span class="pull-right"><i class="glyphicon glyphicon-circle-arrow-right"></i></span>
                                        <div class="clearfix"></div>
                                    </div>
                                </a>
                            </div>
                        </div>
                        <div class="col-md-4">
                            <div class="panel panel-success">
                                <div class="panel-heading">
                                    <div class="row">
                                        <div class="col-xs-3"><i class="glyphicon glyphicon-user"></i></div>
                                        <div class="col-xs-9 text-right"><div class="huge">{$contrib-num}</div><div>Contributors</div></div>
                                    </div>
                                </div>
                                <div class="panel-body collapse" id="contribCount">
                                    {(
                                    <p>This number represents the count of contributors who have authored or revised an entry in <i>{$collection-title}</i> as of {current-date()}.</p>,
                                    <ul style="padding-left: 1em;">{$contributors}</ul>)} 
                                    
                                </div>
                                <a role="button" 
                                    data-toggle="collapse" 
                                    href="#contribCount" 
                                    aria-expanded="false" 
                                    aria-controls="contribCount">
                                    <div class="panel-footer">
                                        <span class="pull-left">View Details</span>
                                        <span class="pull-right"><i class="glyphicon glyphicon-circle-arrow-right"></i></span>
                                        <div class="clearfix"></div>
                                    </div>
                                </a>
                            </div>
                        </div>
                        <div class="col-md-4">
                            <div class="panel panel-info">
                                <div class="panel-heading">
                                    <div class="row">
                                        <div class="col-xs-3"><i class="glyphicon glyphicon-stats"></i></div>
                                        <div class="col-xs-9 text-right"><div class="huge"> {$data-points}</div><div>Data points</div></div>
                                    </div>
                                </div>
                                <div id="dataPoints" class="panel-body collapse">
                                    <p>This number is an approximation of the entire data, based on a count of XML text nodes in the body of each TEI XML document in the <i>{$collection-title}</i> as of {current-date()}.</p>  
                                </div>
                                <a role="button" 
                                data-toggle="collapse" 
                                href="#dataPoints" 
                                aria-expanded="false" 
                                aria-controls="dataPoints">
                                    <div class="panel-footer">
                                        <span class="pull-left">View Details</span>
                                        <span class="pull-right"><i class="glyphicon glyphicon-circle-arrow-right"></i></span>
                                        <div class="clearfix"></div>
                                    </div>
                                </a>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </div>
};

(:
 :NOTE: not being used
:)
declare %templates:wrap function app:get-nav($node as node(), $model as map(*)){
 doc($global:data-root || 'templates/subnav.xml')/child::*
};

(:~  
 : Simple get record function, get tei record based on idno
 : @param $app:id syriaca.org uri 
:)
declare function app:get-rec($node as node(), $model as map(*), $coll as xs:string?) {
if($app:id) then 
    let $id :=
        if(contains(request:get-uri(),'http://syriaca.org/')) then $app:id
        else if($coll = 'places') then concat('http://syriaca.org/place/',$app:id) 
        else if(($coll = 'persons') or ($coll = 'saints') or ($coll = 'authors')) then concat('http://syriaca.org/person/',$app:id)
        else if($coll = 'bhse') then concat('http://syriaca.org/work/',$app:id)
        else if($coll = 'spear') then concat('http://syriaca.org/spear/',$app:id)
        else if($coll = 'mss') then concat('http://syriaca.org/manuscript/',$app:id)
        else $app:id
    return map {"data" := collection($global:data-root)//tei:idno[@type='URI'][. = $id]}
else map {"data" := 'Page data'}    
};

(:~
 : Dynamically build html title based on TEI record and/or sub-module. 
 : @param $app:id if id is present find TEI title, otherwise use title of sub-module
:)
declare %templates:wrap function app:app-title($node as node(), $model as map(*), $coll as xs:string?){
if($app:id) then
   global:tei2html($model("data")/ancestor::tei:TEI/descendant::tei:title[1]/text())
else if($coll = 'places') then 'The Syriac Gazetteer'  
else if($coll = 'persons') then 'The Syriac Biographical Dictionary'
else if($coll = 'q')then 'Gateway to the Syriac Saints'
else if($coll = 'saints') then 'Gateway to the Syriac Saints: Volume II: Qadishe'
else if($coll = 'bhse') then 'Gateway to the Syriac Saints: Volume I: Bibliotheca Hagiographica Syriaca Electronica'
else if($coll = 'spear') then 'A Digital Catalogue of Syriac Manuscripts in the British Library'
else if($coll = 'mss') then concat('http://syriaca.org/manuscript/',$app:id)
else 'Syriaca.org: The Syriac Reference Portal '
};  

(:~
 : Default title display, used if no sub-module title function. 
:)
declare function app:h1($node as node(), $model as map(*)){
    if(($model("data")/ancestor::tei:TEI/descendant::*[contains(@syriaca-tags,'#syriaca-headword')])) then
        let $rec := $model("data")/ancestor::tei:TEI/descendant::tei:body
        let $title-nodes := 
            <srophe-title xmlns="http://www.tei-c.org/ns/1.0">
                {($rec/descendant::*[contains(@syriaca-tags,'#syriaca-headword')], $rec/descendant::tei:idno, $rec/descendant::tei:location)}
            </srophe-title>
        return global:tei2html($title-nodes)
    else global:tei2html($model("data")/ancestor::tei:TEI/descendant::tei:title[1])
}; 

(:~ 
 : Default record display, used if no sub-module functions. 
:)
declare %templates:wrap function app:rec-display($node as node(), $model as map(*), $coll as xs:string?){
    if($model("data")/ancestor::tei:TEI//tei:listRelation) then 
       <div class="row">
            <div class="col-md-8 column1">
                {global:tei2html($model("data")/ancestor::tei:TEI/descendant::tei:body)} 
            </div>
            <div class="col-md-4 column2">
                {rel:build-relationships($model("data")/ancestor::tei:TEI//tei:listRelation)}  
            </div>
        </div>
    else 
        <div class="row">
            <div class="col-md-12 column1">
                {global:tei2html($model("data")/ancestor::tei:TEI/descendant::tei:body)}
            </div>
        </div>
};

(:
 : Return tieHeader info to be used in citation
:)
declare %templates:wrap function app:citation($node as node(), $model as map(*)){
    let $rec := $model("data")/ancestor::tei:TEI
    let $header := 
    <place xmlns="http://www.tei-c.org/ns/1.0">
        <citation xmlns="http://www.tei-c.org/ns/1.0">
            {$rec//tei:teiHeader | $rec//tei:bibl}
        </citation> 
    </place>
    return global:tei2html($header)
};

declare %templates:wrap function app:set-data($node as node(), $model as map(*), $doc as xs:string){
    teiDocs:generate-docs($global:data-root || '/places/tei/78.xml')
};

(:~
 : Builds Dublin Core metadata
 : If id parameter is present use place data to generate metadata
 : @param $metadata:id gets place id from url
 :) 
declare function app:get-dc-metadata(){
    if(exists($id)) then 'get data'
    else ()
};

(:~
 : Generic contact form can be added to any page by calling:
 : <div data-template="app:contact-form"/>
 : with a link to open it that looks like this: 
 : <button class="btn btn-default" data-toggle="modal" data-target="#feedback">CLink text</button>&#160;
:)
declare %templates:wrap function app:contact-form($node as node(), $model as map(*))
{
    <div> 
        <div class="modal fade" id="feedback" tabindex="-1" role="dialog" aria-labelledby="feedbackLabel" aria-hidden="true">
            <div class="modal-dialog">
                <div class="modal-content">
                    <div class="modal-header">
                        <button type="button" class="close" data-dismiss="modal">
                            <span aria-hidden="true">x</span>
                            <span class="sr-only">Close</span>  
                        </button>
                        <h2 class="modal-title" id="feedbackLabel">Corrections/Additions?</h2>
                    </div>
                    <form action="/exist/apps/srophe/modules/email.xql" method="post" id="email" role="form">
                        <div class="modal-body" id="modal-body">
                            <input type="text" name="name" placeholder="Name" class="form-control" style="max-width:300px"/>
                            <br/>
                            <input type="text" name="email" placeholder="email" class="form-control" style="max-width:300px"/>
                            <br/>
                            <input type="text" name="subject" placeholder="subject" class="form-control" style="max-width:300px"/>
                            <br/>
                            <textarea name="comments" id="comments" rows="3" class="form-control" placeholder="Comments" style="max-width:500px"/>
                            <!-- start reCaptcha API-->
                            <script type="text/javascript" src="http://api.recaptcha.net/challenge?k=6Lf1uvESAAAAAPiMWhCCFcyDqj8LVNoBKwkROCia"/>
                            <noscript>
                                <iframe src="http://api.recaptcha.net/noscript?k=6Lf1uvESAAAAAPiMWhCCFcyDqj8LVNoBKwkROCia" height="100" width="100" frameborder="0"/>
                                <br/>
                                <textarea name="recaptcha_challenge_field" rows="3" cols="40"/>
                                <input type="hidden" name="recaptcha_response_field" value="manual_challenge"/>
                            </noscript>
                        </div>
                        <div class="modal-footer">
                            <button class="btn btn-default" data-dismiss="modal">Close</button>
                            <input id="email-submit" type="submit" value="Send e-mail" class="btn"/>
                        </div>
                  </form>
          </div>
       </div>
        </div>
   </div> 
};

(:~
 : Grabs latest news for home page
 : http://syriaca.org/feed/
 :)
 
declare %templates:wrap function app:get-feed($node as node(), $model as map(*)){ 
   let $news := doc('http://syriaca.org/blog/feed/')/child::*
   for $latest at $n in subsequence($news//item, 1, 8)
   return 
   <li>
        <a href="{$latest/link/text()}">{$latest/title/text()}</a>
   </li>
};

(:~
 : Typeswitch to transform confessions.xml into nested list.
 : @param $node   
:)
declare function app:transform($nodes as node()*) as item()* {
    for $node in $nodes
    return 
        typeswitch($node)
            case text() return $node
            case comment() return ()
            case element(tei:list) return element ul {app:transform($node/node())}
            case element(tei:item) return element li {app:transform($node/node())}
            case element(tei:label) return element span {app:transform($node/node())}
            default return app:transform($node/node())
};

(:~
 : Pull confession data for confessions.html
:)
declare %templates:wrap function app:build-confessions($node as node(), $model as map(*)){
    let $confession := doc($global:data-root || '/documentation/confessions.xml')//tei:body/child::*[1]
    return app:transform($confession)
};

(:~   
 : get editors as distinct values
:)
declare function app:get-editors(){
distinct-values(
    (for $editors in collection($global:data-root || '/places/tei')//tei:respStmt/tei:name/@ref
     return substring-after($editors,'#'),
     for $editors-change in collection($global:data-root || '/places/tei')//tei:change/@who
     return substring-after($editors-change,'#'))
    )
};

(:~
 : Build editor list. Sort alphabeticaly
:)
declare %templates:wrap function app:build-editor-list($node as node(), $model as map(*)){
    let $editors := doc($global:app-root || '/documentation/editors.xml')//tei:listPerson
    for $editor in app:get-editors()
    let $name := 
        for $editor-name in $editors//tei:person[@xml:id = $editor]
        return concat($editor-name/tei:persName/tei:forename,' ',$editor-name/tei:persName/tei:addName,' ',$editor-name/tei:persName/tei:surname)
    let $sort-name :=
        for $editor-name in $editors//tei:person[@xml:id = $editor] return $editor-name/tei:persName/tei:surname
    order by $sort-name
    return
        if($editor != '') then 
            if(normalize-space($name) != '') then 
            <li>{normalize-space($name)}</li>
            else ''
        else ''  
};