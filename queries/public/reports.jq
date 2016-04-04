import module namespace http-client = "http://zorba.io/modules/http-client";

declare variable $report external := "COMID-BSC-CF1-ISM-IEMIB-OILY-SPEC6";
[
let $json := parse-json(http-client:get-text("https://www.dropbox.com/s/hviik14gwhxl4kf/COMID-BSC-CF1-ISM-IEMIB-OILY-SPEC6.json?dl=1").body.content)
let $rules := parse-json(http-client:get-text("http://report-frames.28.io/generate.jq?report="||$report).body.content)
for $component in $json
let $rules as object? := $rules[$$.role eq $component.Role]
return copy $c := $component
modify (
    replace value of json $c.Archive with null,
    insert json {  "Owner" : "admin@28.io",
          "Description" : "Report frame against the style "||$report||" (see http://www.xbrlsite.com/2015/fro/us-gaap/html/ReportFrames/ for more information)",
          "ACL" : [ {
            "Type" : "Group",
            "Grantee" : "http://28.io/groups/AllUsers",
            "Permission" : "READ"
          } ],
          "LastModified" : "2015-04-23T09:34:54.006577Z"
    } into $c,
    replace value of json $c.Rules with [ $c.Rules, $rules.end-rules[] ],
    replace value of json $c._id with $report||"-"||tokenize($c.Role, "/")[last()]
)
return $c ]