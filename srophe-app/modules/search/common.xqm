xquery version "3.0";
(:~
 : Shared functions for search modules 
 :)
module namespace common="http://syriaca.org/common";
import module namespace global="http://syriaca.org/global" at "../lib/global.xqm";
import module namespace kwic="http://exist-db.org/xquery/kwic" at "resource:org/exist/xquery/lib/kwic.xql";
import module namespace functx="http://www.functx.com";
declare namespace tei="http://www.tei-c.org/ns/1.0";

(:~
 : Cleans search parameters to replace bad/undesirable data in strings
 : @param-string parameter string to be cleaned
:)
declare function common:clean-string($string){
    common:strip-chars($string)
};

declare function common:strip-chars($string){
let $query-string := $string
let $query-string := 
	   if (functx:number-of-matches($query-string, '"') mod 2) then 
	       replace($query-string, '"', ' ')
	   else $query-string   (:if there is an uneven number of quotation marks, delete all quotation marks.:)
let $query-string := 
	   if ((functx:number-of-matches($query-string, '\(') + functx:number-of-matches($query-string, '\)')) mod 2 eq 0) 
	   then $query-string
	   else translate($query-string, '()', ' ') (:if there is an uneven number of parentheses, delete all parentheses.:)
let $query-string := 
	   if ((functx:number-of-matches($query-string, '\[') + functx:number-of-matches($query-string, '\]')) mod 2 eq 0) 
	   then $query-string
	   else translate($query-string, '[]', ' ') (:if there is an uneven number of brackets, delete all brackets.:)
let $query-string := replace($string,"'","''")	   
return 
    if(matches($query-string,"(^\*$)|(^\?$)")) then 'Invalid Search String, please try again.' (: Must enter some text with wildcard searches:)
    else replace(replace($query-string,'<|>|@',''), '(\.|\[|\]|\\|\||\-|\^|\$|\+|\{|\}|\(|\)|(/))','\\$1') (: Escape special characters. Fixes error, but does not return correct results on URIs see: http://viaf.org/viaf/sourceID/SRP|person_308 :)
};

(:~
 : @depreciated use global:build-sort-string()
 : Strips english titles of non-sort characters as established by Syriaca.org
 : Used for sorting for browse and search modules
 : @param $titlestring 
 :)
declare function common:build-sort-string($titlestring as xs:string*) as xs:string* {
    replace(replace(replace(replace($titlestring,'^\s+',''),'^al-',''),'[‘ʻʿ]',''),'On ','')
};

(:~
 : Search options passed to ft:query functions
:)
declare function common:options(){
    <options>
        <default-operator>and</default-operator>
        <phrase-slop>1</phrase-slop>
        <leading-wildcard>yes</leading-wildcard>
        <filter-rewrite>yes</filter-rewrite>
    </options>
};

(:
 : Build full-text keyword search over full record data 
:)
declare function common:keyword(){
    if(request:get-parameter('q', '') != '') then 
        if(starts-with(request:get-parameter('q', ''),'http://syriaca.org/')) then
           concat("[ft:query(descendant::*,'&quot;",request:get-parameter('q', ''),"&quot;',common:options())]")
        else concat("[ft:query(descendant::*,'",common:clean-string(request:get-parameter('q', '')),"',common:options())]")
    else '' 
};

(:~
 : Add a generic relationship search to any search module. 
:)
declare function common:relation-search(){
if(request:get-parameter('rel', '') != '') then
    let $q := request:get-parameter('rel', '')
    return 
        if(request:get-parameter('relType', '') != '') then
            let $relType := request:get-parameter('relType', '')
            return 
                concat("[descendant::tei:relation[@passive[matches(.,'",$q,"(\W.*)?$')] or @active[matches(.,'",$q,"(\W.*)?$')] or @mutual[matches(.,'",$q,"(\W.*)?$')]][@ref = '",request:get-parameter('relType', ''),"' or @name = '",request:get-parameter('relType', ''),"']]")
        else concat("[descendant::tei:relation[@passive[matches(.,'",$q,"(\W.*)?$')] or @active[matches(.,'",$q,"(\W.*)?$')] or @mutual[matches(.,'",$q,"(\W.*)?$')]]]")
else ''
};

(:~
 : Generic search related places 
:)
declare function common:related-places() as xs:string?{
    if(request:get-parameter('related-place', '') != '') then
        let $related-place := request:get-parameter('related-place', '')
        let $ids := 
            if(matches($related-place,'^http://syriaca.org/')) then
                normalize-space($related-place)
            else 
                string-join(distinct-values(
                    for $r in collection($global:data-root || '/places')//tei:place[ft:query(tei:placeName,$related-place,common:options())]
                    let $id := $r//tei:idno[starts-with(.,'http://syriaca.org')]
                    return $id),'|')                   
        return 
            if($ids != '') then 
                if(request:get-parameter('place-type', '') !='' and request:get-parameter('place-type', '') !='any') then 
                    if(request:get-parameter('place-type', '') = 'birth') then 
                        concat("[descendant::tei:relation[@name ='born-at'][@passive[matches(.,'",$ids,"(\W.*)?$')] or @active[matches(.,'",$ids,"(\W.*)?$')]]]")
                    else if(request:get-parameter('place-type', '') = 'death') then
                        concat("[descendant::tei:relation[@name ='died-at'][@passive[matches(.,'",$ids,"(\W.*)?$')] or @active[matches(.,'",$ids,"(\W.*)?$')]]]")   
                    else if(request:get-parameter('place-type', '') = 'venerated') then 
                        concat("[descendant::tei:event[matches(@contains,'",$ids,"(\W.*)?$')]]")
                    else concat("[descendant::tei:relation[@name ='",request:get-parameter('place-type', ''),"'][@passive[matches(.,'",$ids,"(\W.*)?$')] or @active[matches(.,'",$ids,"(\W.*)?$')]]]")             
                else concat("[descendant::tei:relation[@passive[matches(.,'",$ids,"(\W.*)?$')] or @mutual[matches(.,'",$ids,"(\W.*)?$')] or @active[matches(.,'",$ids,"(\W.*)?$')]]]")
           else ()     
    else ()
};

(:~
 : Generic search related persons 
:)
declare function common:related-persons() as xs:string?{
    if(request:get-parameter('related-persons', '') != '') then
        let $rel-person := request:get-parameter('related-persons', '')
        let $ids := 
            if(matches($rel-person,'^http://syriaca.org/')) then
                normalize-space($rel-person)
            else 
                string-join(distinct-values(
                    for $r in collection($global:data-root || '/persons')//tei:person[ft:query(tei:persName,$rel-person,common:options())]
                    let $id := $r//tei:idno[starts-with(.,'http://syriaca.org')]
                    return $id),'|')   
        return 
            if(request:get-parameter('person-type', '')) then
                let $relType := request:get-parameter('person-type', '')
                return 
                    concat("[descendant::tei:relation[@passive[matches(.,'",$ids,"(\W.*)?$')] or @active[matches(.,'",$ids,"(\W.*)?$')] or @mutual[matches(.,'",$ids,"(\W.*)?$')]][@ref = '",$relType,"' or @name = '",$relType,"']]")
            else concat("[descendant::tei:relation[@passive[matches(.,'",$ids,"(\W.*)?$')] or @mutual[matches(.,'",$ids,"(\W.*)?$')] or @active[matches(.,'",$ids,"(\W.*)?$')]]]")
    else ()
};

(:~
 : Generic search related titles 
:)
declare function common:mentioned() as xs:string?{
    if(request:get-parameter('mentioned', '') != '') then 
        if(matches(request:get-parameter('mentioned', ''),'^http://syriaca.org/')) then 
            let $id := normalize-space(request:get-parameter('mentioned', ''))
            return concat("[descendant::*[@ref[matches(.,'",$id,"(\W.*)?$')]]]")
        else 
            concat("[descendant::*[ft:query(tei:title,'",common:clean-string(request:get-parameter('mentioned', '')),"',common:options())]]")
    else ()  
};

(:~
 : Generic id search
 : Searches record idnos
:)
declare function common:idno() as xs:string? {
    if(request:get-parameter('idno', '') != '') then 
        let $id := replace(request:get-parameter('idno', ''),'[^\d\s]','')
        let $syr-id := concat('http://syriaca.org/work/',$id)
        return concat("[descendant::tei:idno[normalize-space(.) = '",$id,"' or .= '",$syr-id,"']]")
    else ''    
};

(:~
 : Generic URI search
 : Searches record URIs and also references to record ids.
:)
declare function common:uri() as xs:string? {
    if(request:get-parameter('uri', '') != '') then 
        let $q := request:get-parameter('uri', '')
        return 
        concat("
        [ft:query(descendant::*,'&quot;",$q,"&quot;',common:options()) or 
            .//@passive[matches(.,'",$q,"(\W.*)?$')]
            or 
            .//@mutual[matches(.,'",$q,"(\W.*)?$')]
            or 
            .//@active[matches(.,'",$q,"(\W.*)?$')]
            or 
            .//@ref[matches(.,'",$q,"(\W.*)?$')]
            or 
            .//@target[matches(.,'",$q,"(\W.*)?$')]
        ]")
    else ''    
};

(:
 : General search function to pass in any tei element. 
 : @param $element element name must have a lucene index defined on the element
 : @param $query query text to be searched. 
:)
declare function common:element-search($element, $query){
    if(exists($element) and $element != '') then 
        for $e in $element
        return concat("[ft:query(descendant::tei:",$element,",'",common:clean-string($query),"',common:options())]") 
    else '' 
};

