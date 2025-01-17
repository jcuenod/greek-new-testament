(:
    Convert GBI trees to Lowfat format.

	NOTE: this should rarely be used now that the lowfat trees
	are being independently, but I am keeping it in the repo
	for documentation purposes and also for quality assurance,
	as a way of testing the lowfat trees against GBI as we
	move forward.

	If it is used, remember to do the following steps:

	- Search for duplicate IDs, removing the second GBI interpretation when there are duplicate subtrees.
	- Search for the single instance where a word is not in any word group, but directly in a sentence.
	- Do a diff to make sure things make sense.

:)


declare variable $retain-singletons := false();

declare function local:osisBook($nodeId)
{
    switch (xs:integer(substring($nodeId, 1, 2)))
        case 40
            return
                "Matt"
        case 41
            return
                "Mark"
        case 42
            return
                "Luke"
        case 43
            return
                "John"
        case 44
            return
                "Acts"
        case 45
            return
                "Rom"
        case 46
            return
                "1Cor"
        case 47
            return
                "2Cor"
        case 48
            return
                "Gal"
        case 49
            return
                "Eph"
        case 50
            return
                "Phil"
        case 51
            return
                "Col"
        case 52
            return
                "1Thess"
        case 53
            return
                "2Thess"
        case 54
            return
                "1Tim"
        case 55
            return
                "2Tim"
        case 56
            return
                "Titus"
        case 57
            return
                "Phlm"
        case 58
            return
                "Heb"
        case 59
            return
                "Jas"
        case 60
            return
                "1Pet"
        case 61
            return
                "2Pet"
        case 62
            return
                "1John"
        case 63
            return
                "2John"
        case 64
            return
                "3John"
        case 65
            return
                "Jude"
        case 66
            return
                "Rev"
        default return
            "###"
};

declare function local:verbal-noun-type($node)
(:  This realy doesn't work yet. Not even close. :)
{
    switch ($node/parent::Node/@Cat)
        case 'adjp'
            return
                attribute type {'adjectival'}
        case 'advp'
            return
                attribute type {'adverbial'}
        case 'np'
            return
                attribute type {'nominal'}
        default return
           attribute type {'?'}
};

declare function local:head($node)
{
    if ($node)
    then
        let $preceding := count($node/preceding-sibling::Node)
        let $following := count($node/following-sibling::Node)
        return
            if ($preceding + $following > 0)
            then
                if ($preceding = $node/parent::*/@Head and $node/parent::*/@Cat != 'conj')
                then attribute head { true() }
                else ()
            else local:head($node/parent::*)
    else ()

};

declare function local:attributes($node)
{
    $node/@Cat ! attribute class {lower-case(.)},
    $node/@Type ! attribute type {lower-case(.)}[string-length(.) >= 1 and not(. = ("Logical", "Negative"))],
    $node/@morphId ! attribute osisId {local:osisId(.)},
    $node/@nodeId ! attribute n {.},
    $node/@HasDet ! attribute articular {true()},
    $node/@UnicodeLemma ! attribute lemma {.},
    $node/@NormalizedForm ! attribute normalized {.},
    $node/@StrongNumber ! attribute strong {.},
    $node/@Number ! attribute number {lower-case(.)},
    $node/@Person ! attribute person {lower-case(.)},
    $node/@Gender ! attribute gender {lower-case(.)},
    $node/@Case ! attribute case {lower-case(.)},
    $node/@Tense ! attribute tense {lower-case(.)},
    $node/@Voice ! attribute voice {lower-case(.)},
    $node/@Mood ! attribute mood {lower-case(.)},
    $node/@Mood[. = ('Participle', 'Infinitive')] ! attribute type { local:verbal-noun-type($node) },
    $node/@Degree ! attribute degree {lower-case(.)},
    local:head($node),
    $node[empty(*)] ! attribute discontinuous {"true"}[$node/following::Node[empty(*)][1]/@morphId lt $node/@morphId],
    $node/@Rule ! attribute rule {.}
};

declare function local:osisId($nodeId)
{
    concat(local:osisBook($nodeId),
    ".",
    xs:integer(substring($nodeId, 3, 3)),
    ".",
    xs:integer(substring($nodeId, 6, 3)),
    "!",
    xs:integer(substring($nodeId, 9, 3))
    )
};


declare function local:osisVerseId($nodeId)
{
    concat(local:osisBook($nodeId),
    ".",
    xs:integer(substring($nodeId, 3, 3)),
    ".",
    xs:integer(substring($nodeId, 6, 3))
    )
};

declare function local:oneword($node)
(: If the Node governs a single word, return that word. :)
{
     if (count($node/Node) > 1)
     then ()
     else if ($node/Node)
     then local:oneword($node/Node)
     else $node
};

declare function local:sub-CL-adjunct($node)
{
};

declare function local:sub-CL-adjunct-parent($node)
{

       let $first := $node/Node[1]
       let $second := $node/Node[2]
       return
         if ($first[@Rule='sub-CL']) then
              <wg>
                {
                  local:attributes($second),
                  <!-- one -->,
                  $first ! local:node(.),
                  $second/Node ! local:node(.)
                }
              </wg>
         else if ($second[@Rule='sub-CL']) then
               <wg>
                {
                  local:attributes($first),
                  <!-- two -->,
                  $first/Node ! local:node(.),
                  $second ! local:node(.)
                }
              </wg>
          else <error>{ "Something went wrong.",  "First:", $first, "Second:", $second }</error>
};

declare function local:is-worth-preserving($clause)
{
    local:node-type($clause/parent::*) = 'role'
    or $clause/@Rule='sub-CL'
    or not($clause/@Rule=('ClCl','ClCl2'))
};

declare function local:clause($node)
(:  This is probably too simple as written - need to do restructuring of clauses based on @rule attributes  :)
{
      if (local:is-worth-preserving($node))
      then       
        <wg>
          {
              local:attributes($node),
              $node/Node ! local:node(.)
          }
        </wg>
      else        
        $node/Node ! local:node(.)      
};


declare function local:phrase($node)
{
    if (local:oneword($node))
    then (local:word(local:oneword($node)))
    else
        <wg>
          {
            local:attributes($node),
            $node/Node ! local:node(.)
          }
        </wg>
};

declare function local:role($node)
(:
  A role node can have more than one child in some
  corner cases in the GBI trees, e.g. Gal 4:18, where
  an ADV node contains ADV conj ADV.  I imagine this
  occurs only for conjunctions, but I am not sure.
:)
{
    let $role := attribute role {lower-case($node/@Cat)}
    return
        if (local:oneword($node))
        then (local:word(local:oneword($node), $role))
        else  if (count($node/Node) > 1)
        then
            <wg>
                {
                    $role,
                    $node/Node ! local:node(.)
                }
            </wg>
        else
            <wg>
                {
                    $role,
                    local:attributes($node/Node),
                    $node/Node/Node ! local:node(.)
                }
            </wg>
};

declare function local:word($node)
{
    local:word($node, ())
};

declare function local:word($node, $role)
(: $role can contain a role attribute or a null sequence :)
{
    if ($node/*)
    then ( element error {$role, $node }) else
    if (string-length($node) = string-length($node/@Unicode) + 1)
    then
        (: place punctuation in a separate node :)
        (
        <w>
            {
                $role,
                local:attributes($node),
                substring($node, 1, string-length($node) - 1)
            }
        </w>,
        <pu>{substring($node, string-length($node), 1)}</pu>
        )
    else
        <w>
            {
                $role,
                local:attributes($node),
                string($node)
            }
        </w>
};

declare function local:node-type($node as element(Node))
{
    if ($node/@UnicodeLemma)
      then "word"
    else
    switch ($node/@Cat)
        case "adj"
        case "adv"
        case "conj"
        case "det"
        case "noun"
        case "num"
        case "prep"
        case "ptcl"
        case "pron"
        case "verb"
        case "intj"
	    case "adjp"
        case "advp"
        case "np"
        case "nump"
        case "pp"
        case "vp"
            return
                "phrase"
        case "S"
        case "IO"
        case "ADV"
        case "O"
        case "O2"
        case "P"
        case "V"
        case "VC"
            return
                "role"
        case "CL"
            return
                "clause"
        default
        return "####"
};

declare function local:node($node as element(Node))
{
    switch (local:node-type($node))
        case "word"
            return
                local:word($node)
        case "phrase"
            return
                local:phrase($node)
        case "role"
            return
                local:role($node)
        case "clause"
            return
                local:clause($node)
        default
        return
            $node
};

declare function local:straight-text($node)
{
    for $n at $i in $node//Node[local:node-type(.) = 'word']
    order by $n/@morphId
    return string($n/@Unicode)
};

declare function local:sentence($node)
{
    <sentence>
        {
            <p>
              {
                for $verse in distinct-values($node//Node/@morphId ! local:osisVerseId(.))
                return (
                    <milestone unit="verse">
                        { attribute id { $verse }, $verse}
                    </milestone>
                    ,
                    " "
                )
              }
              { local:straight-text($node) }
             </p>,

             if (count($node/Node) > 1 or not($node/Node/@node = 'CL'))
             then <wg role="cl">{ $node/Node ! local:node(.) }</wg>
             else local:node($node/Node)

        }
    </sentence>
};

processing-instruction xml-stylesheet {'href="treedown.css"'},
processing-instruction xml-stylesheet {'href="boxwood.css"'},
<book>
    {
        (:
            If a sentence has multiple interpretations, Sentence/Trees may contain
            multiple Tree nodes.  We want only the first.
        :)
        for $sentence in //Tree[1]/Node
        return
            local:sentence($sentence)
    }
</book>
