//
//  Serialization.swift
//  SimplePreferencePropagation
//
//  Created by Dragos Mihaita Iftimie on 24/08/2021.
//

import Foundation

public struct SerializationSeparators{
    static let attrTaxSeparator:String = "&&&"
    static let attrSeparator:String = "^^^"
}

extension Schema{
    public static func fromStringDeserialization(schema:String) throws -> Schema{
        let dividedSchema = schema.components(separatedBy: SerializationSeparators.attrTaxSeparator)
        var attrs:[Attribute] = []
        var taxs:[Taxonomy] = []
        for attrTax in dividedSchema{
            attrs.append(attrTax.components(separatedBy: SerializationSeparators.attrSeparator)[0].trimmingCharacters(in: .whitespacesAndNewlines))
            taxs.append(try Taxonomy.init(from: attrTax.components(separatedBy: SerializationSeparators.attrSeparator)[1].trimmingCharacters(in: .whitespacesAndNewlines)))
        }
        return Schema.init(attributes: attrs, taxonomies: taxs)
    }
    
    public func toStringSerialization() -> String{
        var res = ""
        var index = 0
        for (attr,tax) in self.attribute2Taxonomy{
            if index != 0 {
                res += SerializationSeparators.attrTaxSeparator + String("\n")
            }
            res += attr + String("\n") + SerializationSeparators.attrSeparator + String("\n")
            res += tax.toStringSerialization() + String("\n")
            index += 1
        }
        return res
    }
}

extension Taxonomy{
    
    public func toStringSerialization() -> String{
        var res = ""
        let maximals = self.maximalValues
        if maximals.count > 1 || !(maximals.first?.name == Value.topValueName){
            for maximal in maximals{
                res += maximal.name + String(ParserStrings.taxonomyEntrySeparator) + Value.topValueName + String(ParserStrings.taxonomyEntryTerminator) + String("\n")
            }
        }
        for maximal in maximals{
            self.addChildrenRecursevly(node: maximal, buffer: &res)
        }
        return res
    }
    
    private func addChildrenRecursevly(node:Value,buffer: inout String){
        let children = self.valuesDirectlyBelow(value: node)
        if children.isEmpty {
            return
        }else{
            for child in children{
                let tmpString = child.name + String(ParserStrings.taxonomyEntrySeparator) + node.name + String(ParserStrings.taxonomyEntryTerminator)
                if !buffer.contains(string: tmpString){
                    buffer += tmpString + String("\n")
                }
                self.addChildrenRecursevly(node: child, buffer: &buffer)
            }
        }
    }
}
