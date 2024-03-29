import module namespace http-client = "http://zorba.io/modules/http-client";

declare variable $report external := "CashFlowStatement";

declare variable $links as object :=
{
  "GeneralInformation" : "https://www.dropbox.com/s/7lke55tif1l7zk4/components.json?dl=1",
  "BalanceSheetClassified" : "https://www.dropbox.com/s/wbyqwvr7ansbxnt/components.json?dl=1",
  "BalanceSheetUnclassified" : "https://www.dropbox.com/s/m4f2j402azmh7ss/components.json?dl=1",
  "CashFlowStatement" : "https://www.dropbox.com/s/vu5t5448103wq9i/components.json?dl=1",
  "CashFlowStatement2" : "https://www.dropbox.com/s/v8fyy5derwiaam7/components.json?dl=1",
  "IncomeStatementInterestBasedRevenues" : "https://www.dropbox.com/s/kpw91cplmrom541/components.json?dl=1",
  "IncomeStatementSingleStep_Special6" : "https://www.dropbox.com/s/6pdqmcnwjj25rj4/components.json?dl=1"
};

[
let $json := parse-json(http-client:get-text($links.$report).body.content)
let $rules := parse-json(http-client:get-text("http://report-frames.28.io/generate-new.jq?report="||$report).body.content)
for $component in $json
where $component.Role ne "http://www.xbrl.org/2003/role/link"
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
          "LastModified" : "2015-04-23T09:34:54.006577Z",
          "DefinitionModels" : [ {
              "ModelKind" : "DefinitionModel",
              "Labels" : [ "Fundamental Accounting Concepts" ],
              "Parameters" : {

              },
              "Breakdowns" : {
                "x" : [ {
                  "BreakdownLabels" : [ "Reporting Entity Breakdown" ],
                  "BreakdownTrees" : [ {
                    "Kind" : "Rule",
                    "Abstract" : true,
                    "Labels" : [ "Reporting Entity [Axis]" ],
                    "Children" : [ {
                      "Kind" : "Aspect",
                      "Aspect" : "xbrl:Entity"
                    } ]
                  } ]
                }, {
                  "BreakdownLabels" : [ "Fiscal Year Breakdown" ],
                  "BreakdownTrees" : [ {
                    "Kind" : "Rule",
                    "Abstract" : true,
                    "Labels" : [ "Fiscal Year [Axis]" ],
                    "Children" : [ {
                      "Kind" : "Aspect",
                      "Aspect" : "xbrl28:FiscalYear"
                    } ]
                  } ]
                }, {
                  "BreakdownLabels" : [ "Fiscal Period Breakdown" ],
                  "BreakdownTrees" : [ {
                    "Kind" : "Rule",
                    "Abstract" : true,
                    "Labels" : [ "Fiscal Period [Axis]" ],
                    "Children" : [ {
                      "Kind" : "Aspect",
                      "Aspect" : "xbrl28:FiscalPeriod"
                    } ]
                  } ]
                } ],
                "y" : [ {
                  "BreakdownLabels" : [ "Breakdown on concepts" ],
                  "BreakdownTrees" : [ {
                    "Kind" : "ConceptRelationship",
                    "LinkName" : "link:presentationLink",
                    "LinkRole" : $c.Role,
                    "ArcName" : "link:presentationArc",
                    "ArcRole" : "http://www.xbrl.org/2003/arcrole/parent-child",
                    "RelationshipSource" : $c.Concepts[][$$.Kind eq "LineItems"].Name,
                    "FormulaAxis" : "descendant",
                    "Generations" : 0
                  } ]
                } ]
              },
              "TableFilters" : {

              }
            }
          ]
    } into $c,
    replace value of json $c.Rules with [ $c.Rules, $rules.end-rules[] ],
    replace value of json $c._id with tokenize($c.Role, "/")[last()]
)
return $c ]
