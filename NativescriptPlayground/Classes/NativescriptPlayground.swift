//
//  Created by Rob Laverty on 10/6/16.
//

import Foundation
import Contacts
import Bolts
import FMDB



public typealias OtherContactsHandler = (_ contacts : [CNContact] , _ error : NSError?) -> Void
public typealias recognizeHandler = (_ error : NSError?) -> Void

public struct SQLiteStatement {
	var query: String
	var values: [String]
}

@objc open class BoltThreads: NSObject {
    
    var contactsStore: CNContactStore?
    
    open func getContacts() {
        getContactsAsync( {(contacts, error) in
            if (error == nil) {
                print(contacts)
            }
        })
    }
    
    open func getContactsAsync(_ completion:  @escaping OtherContactsHandler) {
        
        if contactsStore == nil {
            contactsStore = CNContactStore()
        }
        
        getContactsOnBackgroundThread { (contactsArray) in
            completion(contactsArray, nil)
        }
    }
    
    open func getContactsOnBackgroundThread ( completion:@escaping (_ contacts:[CNContact])->()) {
        
        DispatchQueue.global(qos: .userInitiated).async(execute: { () -> Void in
            var contactsArray = [CNContact]()
            let contactFetchRequest = CNContactFetchRequest(keysToFetch: self.allowedContactKeys())
            
            do {
                try self.contactsStore?.enumerateContacts(with: contactFetchRequest, usingBlock: { (contact, stop) -> Void in
                    if contact.phoneNumbers.count > 0 {
                        contactsArray.append(contact)
                    }
                })
            }
                
            catch let error as NSError {
                print(error.localizedDescription)
            }
            
            DispatchQueue.main.async(execute: { () -> Void in
                completion(contactsArray)
            })
        })
    }
    
    open func allowedContactKeys() -> [CNKeyDescriptor] {
        return [CNContactNamePrefixKey as CNKeyDescriptor,
                CNContactGivenNameKey as CNKeyDescriptor,
                CNContactFamilyNameKey as CNKeyDescriptor,
                CNContactOrganizationNameKey as CNKeyDescriptor,
                CNContactBirthdayKey as CNKeyDescriptor,
                CNContactImageDataKey as CNKeyDescriptor,
                CNContactThumbnailImageDataKey as CNKeyDescriptor,
                CNContactImageDataAvailableKey as CNKeyDescriptor,
                CNContactPhoneNumbersKey as CNKeyDescriptor,
                CNContactEmailAddressesKey as CNKeyDescriptor,
        ]
	}
	
	open func getContactsBolts() -> [BFTask<CNContact>] {
		let task = BFTaskCompletionSource<AnyObject>()
		
		getContactsAsync( {(contacts: [CNContact], error) in
			if (error == nil) {
				task.setResult(contacts as [CNContact] as AnyObject?)
			} else {
				task.setError(error!)
			}
		})
		
		let sendi: AnyObject = task.task
		return sendi as! [BFTask<CNContact>]
	}
	
	
	
	
	

	
    open func sqlWriteAsync(_path: String, _statements: [SQLiteStatement]) -> BFTask<AnyObject> {
		let task = BFTaskCompletionSource<AnyObject>()
		
		let queue: FMDatabaseQueue = FMDatabaseQueue.init(path: _path)
		queue.inTransaction { db, rollback in
			do {
                for statement in _statements {
					print(statement)
                    print(statement.query)
					print(statement.values)
                    
                    try db?.executeUpdate(statement.query, values: statement.values)
                }
                task.setResult(true as AnyObject?)
			} catch {
				print(error)
                task.setError(error)
			}
		}
		
		return task.task
	}
	
	
	
	
	
//    open func recognizeAsyncBolts(TESS: G8Tesseract) -> BFTask<AnyObject> {
//        let task = BFTaskCompletionSource<AnyObject>()
//        
//        recognizeOnBackgroundThread(TESS: TESS, completion: {() -> Void in
//            task.setResult(nil)
//        })
//        
//        let sendi: Any = task.task
//        return sendi as! BFTask<AnyObject>
//    }
//    
//    open func recognizeOnBackgroundThread ( TESS: G8Tesseract, completion:@escaping() -> Void) {
//        
//        DispatchQueue.global(qos: .userInitiated).async(execute: { () -> Void in
//            TESS.recognize()
//            DispatchQueue.main.async(execute: { () -> Void in
//                completion()
//            })
//        })
//    }
    
    
    
    
    
    
    
    
    
    
    
    
    
    
}
