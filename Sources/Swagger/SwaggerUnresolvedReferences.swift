//
//  SwaggerUnresolvedReferences.swift
//  
//
//  Created by Alberto Lagos on 5/19/22.
//

import Foundation

public final class SwaggerUnresolvedReferences {
    private static var _references = [String: Set<String>]()
    
    static func add(reference: String, for object: String) {
        if !_references.keys.contains(object) {
            _references[object] = []
        }
        
        _references[object]?.insert(reference)
    }
}
