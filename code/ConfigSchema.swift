//
//  ConfigSchema.swift
//  SimplePreferencePropagation
//
//  Created by Dragos Mihaita Iftimie on 13/08/2021.
//

import Foundation


enum RuledBasedConfigTaxError:Error{
    case RuleWithGivenValueNotFound(value:String)
    case DifferentLeafRulesLength(leaf:String,rulesLength:Int)
    case LeafNotFoundInRules(leaf:String)
}

enum QueryBasedConfigTaxError:Error{
    case NoCommonChildrenQueryProvided(taxonomy:String)
}


public struct ConfigSchema{
     let retriever:TaxonomyRetriever
     let attribute2ConfigTaxonomy: [Attribute:ConfigTaxonomy]
    
    init(conn:TaxonomyRetriever,attrTax:[Attribute:ConfigTaxonomy]){
        self.retriever = conn
        self.attribute2ConfigTaxonomy = attrTax
    }
}


public class ConfigTaxonomy:Hashable{
    public static func == (lhs: ConfigTaxonomy, rhs: ConfigTaxonomy) -> Bool {
        if let _ = lhs as? EmptyConfigTax,let _ = rhs as? EmptyConfigTax{
            return true
        }
        if let l = lhs as? RuleBasedConfigTax,let r = rhs as? RuleBasedConfigTax{
            return Set<Rule>(l.rules) == Set<Rule>(r.rules)
        }
        if let l = lhs as? QueryBasedConfigTax,let r = rhs as? QueryBasedConfigTax{
            return Set<String>(l.getQueries4Fixed()) == Set<String>(r.getQueries4Fixed()) && l.getQuery4CommonChildren(nodes: Set<String>(["placeholder"])) == r.getQuery4CommonChildren(nodes: Set<String>(["placeholder"]))
        }
        return false
    }
    public func hash(into hasher: inout Hasher) {
        hasher.combine(1)
    }
    //questa classe non dovrebbe essere istanziabile, in swift non esiste il concetto di classe astratta pero' :/
     init(){
    }
}

public class RuleBasedConfigTax:ConfigTaxonomy{
    let rules:[Rule]
    let parser:MultidimensionalPointParser
    public init(rules r:[Rule],parser:MultidimensionalPointParser) throws {
        if Set(r.map{$0.getDim()}).count != 1 || r.count == 0{
            throw RuleError.DifferentRulesLengthError(rules: "\(r)")
        }
        self.rules = r
        self.parser = parser
    }
    
    
    public func getDim() -> Int{
        return self.rules[0].getDim()
    }
    
    public func getRuleByValue(value:String) throws -> Rule {
        for rule in self.rules{
            if rule.value == value{
                return rule
            }
        }
        throw RuledBasedConfigTaxError.RuleWithGivenValueNotFound(value: value)
    }
    
    public func getStaticValues() -> [String]{
        var res:[String] = []
        for rule in self.rules{
            res.append(rule.value)
        }
        return res
    }
    
    public func getFathers(leaf:String) throws -> [Value]{
        return try self.getFathers(leaf: self.parser.parse(value: leaf))
    }
    
    public func getFathers(leaf:[Double]) throws -> [Value]{
        if leaf.count != self.getDim(){
            throw RuledBasedConfigTaxError.DifferentLeafRulesLength(leaf: "\(leaf)", rulesLength: self.getDim())
        }
        var res:[String] = []
        for rule in self.rules{
            if try rule.isContained(points: leaf){
                res.append(rule.value)
            }
        }
        if res.count == 0 {
            throw RuledBasedConfigTaxError.LeafNotFoundInRules(leaf: "\(leaf)")
        }
        return res.map(){Value.init(name: $0)}
    }
    
    override public func hash(into hasher:inout Hasher){
        for rule in rules.sorted(by: {$0.description > $1.description}){
            hasher.combine(rule.description)
        }
    }
}


public class QueryBasedConfigTax:ConfigTaxonomy{
     var query4Fixed:[StaticTaxonomyQuery]
     var query4Leaves:[DynamicTaxonomyQuery]
     var query4CommonChildren:CommonChildrenTaxonomyQuery
    
    public init(fixed:[StaticTaxonomyQuery],dynamic:[DynamicTaxonomyQuery],common:CommonChildrenTaxonomyQuery) throws{
        self.query4Fixed = fixed
        self.query4Leaves = dynamic
        var commonTemplates:[CommonChildrenTemplate] = dynamic.compactMap({q in q.template as? CommonChildrenTemplate})
        commonTemplates.append(contentsOf: common.templates)
        self.query4CommonChildren = CommonChildrenTaxonomyQuery.init(templates: commonTemplates)
        if self.query4CommonChildren.templates.isEmpty{
            throw QueryBasedConfigTaxError.NoCommonChildrenQueryProvided(taxonomy:"")
        }
    }
    
    public func getQueries4Fixed() -> [String] {
        return self.query4Fixed.map({$0.getQuery()})
    }
    
    public func getQueries4Leaves(leaf: String) -> [String] {
        return self.query4Leaves.map({$0.getQuery(leaf: leaf)})
    }
    
    public func getQuery4CommonChildren(nodes: Set<String>) -> String {
        return self.query4CommonChildren.getQuery(nodes: nodes)
    }
    override public func hash(into hasher: inout Hasher) {
           hasher.combine(self.getQueries4Fixed())
           hasher.combine(self.getQuery4CommonChildren(nodes: Set<String>(["placeholder"])))
       }
}

public class EmptyConfigTax:ConfigTaxonomy{
    public override init(){

    }
}


extension ConfigSchema:Hashable{
    public static func == (lhs: ConfigSchema, rhs: ConfigSchema) -> Bool {
        var equals:Bool = true
        if Set<Attribute>(lhs.attribute2ConfigTaxonomy.keys) != Set<Attribute>(rhs.attribute2ConfigTaxonomy.keys){
            return false
        }
        for (lKey,lElem) in lhs.attribute2ConfigTaxonomy{
            if rhs.attribute2ConfigTaxonomy[lKey] != lElem{
                equals = false
            }
        }
        return equals
    }
    
    public func hash(into hasher: inout Hasher) {
        for tuple in self.attribute2ConfigTaxonomy.sorted(by: {$0.key > $1.key}){
            hasher.combine(tuple.key)
            hasher.combine(tuple.value)
        }
    }
}
