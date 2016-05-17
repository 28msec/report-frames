import module namespace http-client = "http://zorba.io/modules/http-client";
declare namespace link = "http://www.xbrl.org/2003/linkbase";
declare namespace xlink = "http://www.w3.org/1999/xlink";
declare namespace generic = "http://xbrl.org/2008/generic";
declare namespace va = "http://xbrl.org/2008/assertion/value";

string-join(
let $json as node() := parse-xml(http-client:get-text("http://www.xbrlsite.com/2016/fac/v3/Documentation/Documentation-Networks.xsd").body.content)
for $link in $json/xs:schema/xs:annotation/xs:appinfo/link:linkbaseRef/string(@xlink:href)
return replace($link, ".*/Network-(.*)-relations.xml", "$1"),
"\", \""
)