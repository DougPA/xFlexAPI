//
//  FileHelper.swift
//  xFlexAPI
//
//  Created by Douglas Adams on 8/19/14.
//

import Foundation

// ----------------------------------------------------------------------------
// MARK: - FileHelper Class
// ----------------------------------------------------------------------------

public class FileHelper : NSObject {
    
    // ----------------------------------------------------------------------------
    // MARK: - Class Methods
    
    //
    // Save an array to a file
    //
    public class func writeArray( _ anArray:[AnyObject], toUserFile filePath:String ) {
        (anArray as NSArray).write(toFile: filePath, atomically: true)
    }
    //
    // Save an array to a URL
    //
    public class func writeArray( _ anArray:[AnyObject], toURL url: URL ) -> Bool {
        return (anArray as NSArray).write(to: url, atomically: true)
    }
    //
    // Save a dictionary to a file
    //
    public class func writeDictionary( _ aDictionary:[NSObject:AnyObject], toUserFile filePath:String ) {
        (aDictionary as NSDictionary).write(toFile: filePath, atomically: true)
    }
    //
    // Save a dictionary to a URL
    //
    public class func writeDictionary( _ aDictionary:[NSObject:AnyObject], toURL url: URL ) -> Bool {
        return (aDictionary as NSDictionary).write(to: url, atomically: true)
    }
    //
    // Return the folder (as a URL) for App specific files
    //
    public class func appFolder() -> URL {
        let fileManager = FileManager()
        let urls = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask ) as [URL]
        
        let appFolder = urls.first!.appendingPathComponent( Bundle.main.bundleIdentifier! )
        // does the folder exist?
        if !fileManager.fileExists( atPath: appFolder.path ) {
            // NO, create it
            do {
                try fileManager.createDirectory( at: appFolder, withIntermediateDirectories: false, attributes: nil)
            } catch let error as NSError {
                Log.sharedInstance.entry("Error creating App Support folder: \(error.localizedDescription)", level: .debug, source: "FileHelper")
            }
        }
        return appFolder
    }
    //
    // Determine if a folder / file exists at the specified Path
    //
    public class func pathExists( _ path:String ) -> Bool {
        let fileManager = FileManager.default
        return fileManager.fileExists( atPath: path )
    }
    //
    // Return a Dictionary with the contents of a file (if any) in the User's Application Support folder
    //
    public class func dictionaryForFile( _ fileName:String, ofType fileType:String, fromBundle bundle:Bundle, folder:String ) -> [NSObject:AnyObject] {
        var theDict: [NSObject:AnyObject]
        
        let userFilePath = appFolder().path + "/" + folder + "/" + fileName + "." + fileType
        
        if pathExists( userFilePath ) {
            // user file exists
            theDict = NSDictionary( contentsOfFile: userFilePath)! as [NSObject : AnyObject]
        } else {
            // no User file exists, use the default file
            let defaultFilePath = bundle.path(forResource: folder + "/" + fileName, ofType: fileType )
            theDict = NSDictionary( contentsOfFile: defaultFilePath! )! as [NSObject : AnyObject]
            // create a User version of the file
            writeDictionary( theDict, toUserFile: userFilePath )
        }
        return theDict
    }
    //
    // Return a Dictionary with the contents of a file
    //
    public class func dictionaryForFile( _ fileName:String, ofType fileType:String, path:String ) -> [NSObject:AnyObject] {
        var theDict = NSDictionary()
        let fullPath = path + "/" + fileName + "." + fileType
        
        if pathExists( fullPath ) {
            // user file exists
            theDict = NSDictionary( contentsOfFile: fullPath)!
        }
        return theDict as [NSObject : AnyObject]
    }
    //
    // Return a Dictionary given a URL
    //
    public class func dictionaryForURL( _ url: URL ) -> [NSObject:AnyObject] {
        var theDict = NSDictionary()
        
        if pathExists( url.path ) {
            // user file exists
            theDict = NSDictionary( contentsOfFile: url.path)!
        }
        return theDict as [NSObject : AnyObject]
    }
    //
    // Return a Mutable Dictionary with the contents of a file in the User domain (if it exists)
    //
    public class func mutableDictionaryForFile( _ fileName:String, ofType fileType:String, fromBundle bundle:Bundle, folder:String ) -> NSMutableDictionary {
        return (dictionaryForFile(fileName, ofType: fileType, fromBundle: bundle, folder: folder ) as NSDictionary).mutableCopy() as! NSMutableDictionary
    }
    //
    // Return an Array with the contents of a file in the User domain (if it exists)
    //
    public class func arrayForFile( _ fileName:String, ofType fileType:String, fromBundle bundle:Bundle ) -> [AnyObject] {
        var theArray: NSArray
        
        let userFilePath = appFolder().path + "/" + fileName + "." + fileType
        if pathExists( userFilePath ) {
            // user file exists
            theArray = NSArray(contentsOfFile: userFilePath )!
        } else {
            // no user file exists, use the default file
            let defaultFilePath = bundle.path(forResource: fileName, ofType: fileType )
            theArray = NSArray(contentsOfFile: defaultFilePath! )!
            // create a user version of the file
            writeArray(theArray as [AnyObject], toUserFile: userFilePath )
        }
        return theArray as [AnyObject]
    }
    //
    // Return an Array given a URL
    //
    public class func arrayForURL( _ url: URL ) -> [AnyObject] {
        var theArray = NSArray()
        
        if pathExists( url.path ) {
            // user file exists
            theArray = NSArray(contentsOfFile: url.path )!
        }
        return theArray as [AnyObject]
    }
    //
    // Return a Mutable Array with the contents of a file in the User domain (if it exists)
    //
    public class func mutableArrayForFile( _ fileName:String, ofType fileType:String, fromBundle bundle:Bundle ) -> NSMutableArray {
        return (arrayForFile(fileName, ofType: fileType, fromBundle: bundle ) as NSArray).mutableCopy() as! NSMutableArray
    }
    //
    //
    //
    public class func findFiles( _ path:String, fileExtension:String ) -> [(name:String, path:String)] {
        var arrayOfFiles: [(name:String, path:String)] = []
        
        // find files in the path
        if pathExists( path ) {
            let fileManager = FileManager.default
            let enumerator = fileManager.enumerator( atPath: path )
            // select only the files with the specified extension
            while let file = enumerator?.nextObject() {
                if (file as AnyObject).pathExtension == fileExtension {
                    arrayOfFiles.append( (name: (file as AnyObject).lastPathComponent!, path: path) )
                }
            }
        }
        return arrayOfFiles
    }
    //
    // Delay the execution of the passed closure (delay is in seconds)
    //
    public class func delay(_ delay:Double, closure:@escaping ()->()) {
        //
        DispatchQueue.main.asyncAfter( deadline: DispatchTime.now() + Double(Int64(delay * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC), execute: closure)
    }
    
}
