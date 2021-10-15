//
//  GerarchyElement.swift
//  SimplePreferencePropagation
//
//  Created by Dragos Mihaita Iftimie on 16/09/2021.
//

import Foundation

public enum LevelledGerarchyElementError:Error{
    case LevelOfNodeIsNegative(node:String)
}

public protocol GerarchyElement:Hashable,CustomStringConvertible{}

public class LevelledGerarchyElement<T:GerarchyElement>:GerarchyElement{
    public var description: String {get {return self.descr()}}
    let node:T
    let level:Int
    
    public init(node:T,level:Int) throws {
        self.node = node
        if level < 0 {
            throw LevelledGerarchyElementError.LevelOfNodeIsNegative(node: node.description)
        }
        self.level = level
    }
    
    public func getNode() -> T{
        return self.node
    }
    
    private func descr() -> String{
        return self.node.description + " \(self.level)"
    }
    
    public func getLevel() -> Int {
        return self.level
    }
    public static func == (lhs: LevelledGerarchyElement<T>, rhs: LevelledGerarchyElement<T>) -> Bool {
        return lhs.getNode() == rhs.getNode() && lhs.getLevel() == rhs.getLevel()
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(node)
        hasher.combine(level)
    }
}

public class HigherThanRelation<T:GerarchyElement>{
    let higher:T
    let lower:T
    
    public func getHigherElement() -> T{
        return self.higher
    }
    
    public func getLowerElement() -> T{
        return self.lower
    }
    
    public init(higher:T,lower:T) throws{
        if higher == lower{
            throw LevelledHigherThanRelationError.HigherNodeIsEqualToLowerNode
        }
        self.higher = higher
        self.lower = lower
    }
}

enum LevelledHigherThanRelationError:Error{
    case HigherNodeIsEqualToLowerNode
    case HigherNodeLevelIsLowerThanLower(higher:String,lower:String)
}

public class LevelledHigherThanRelation<R:GerarchyElement,T:LevelledGerarchyElement<R>>:HigherThanRelation<T>{
    override init(higher:T,lower:T) throws {
        if higher.level >= lower.level{
            throw LevelledHigherThanRelationError.HigherNodeLevelIsLowerThanLower(higher: higher.description, lower: lower.description)
        }
        try super.init(higher: higher, lower: lower)
    }
}



public struct TuplesResult:GerarchyElement{
    public var description: String {get{return self.descr()}}
    let tuples:Set<Tuple>
    
    private func descr() -> String{
        return tuples.description
    }
    
    public init(tuples:Set<Tuple>){
        self.tuples = tuples
    }
}

public enum PreQueryNodeError:Error{
    case PreQueryHasMoreValuesOfSameAttribute
}

public struct NodeValue:Hashable{
    let value:Set<Value>
    let attribute:Attribute
    init(value:Set<Value>,attribute:Attribute){
        self.value = value
        self.attribute = attribute
    }
}

public struct PreQueryNode:GerarchyElement{
    public var description: String {get {self.desc()} }
    var values:Set<NodeValue>
    
    private init(){
        self.values = Set<NodeValue>()
    }
    
    init(values:Set<NodeValue>) throws{
        let numberOfValues = values.count
        let numberOfAttributes = Set<String>(values.map({$0.attribute})).count
        if numberOfValues != numberOfAttributes {
            throw PreQueryNodeError.PreQueryHasMoreValuesOfSameAttribute
        }
        self.values = Set<NodeValue>(values.map({NodeValue.init(value: $0.value, attribute: $0.attribute)}))
    }
    
    func haveAtLeastACommonValue(other:PreQueryNode) -> Bool{
        return !self.values.intersection(other.values).isEmpty
    }
    
    private func attributesAreCompatible(attributes:Set<Attribute>) -> Bool {
        return self.getInvolvedAttributes().isDisjoint(with: attributes)
    }
    
    func getInvolvedAttributes() -> Set<Attribute>{
        return Set<Attribute>(self.values.map({$0.attribute}))
    }
    
    func nodeIsCompatible(other:PreQueryNode) -> Bool{
        return self.attributesAreCompatible(attributes: other.getInvolvedAttributes())
    }
    
    static func mergeNodes(node1:PreQueryNode,node2:PreQueryNode) throws -> PreQueryNode{
        var newNode = PreQueryNode.init()
        try newNode.mergeNode(other: node1)
        try newNode.mergeNode(other: node2)
        return newNode
    }
    
    mutating func mergeNode(other:PreQueryNode) throws{
        for value in other.values{
            try self.addValue(value: value)
        }
    }
    
   private mutating func addValue(value:NodeValue) throws{
        if self.values.map({$0.attribute}).contains(value.attribute) {
            throw PreQueryNodeError.PreQueryHasMoreValuesOfSameAttribute
        }
    self.values.insert(NodeValue.init(value: value.value, attribute: value.attribute))
    }
    
    private func desc() -> String{
        var str = "("
        var index = 0
        for val in values {
            if index > 0 {
                str += "|"
            }
            for value in val.value{
                str += " " + value.name + " "
            }
            str += "[\(val.attribute)]"
            index += 1
        }
        return str + ")"
    }
}

