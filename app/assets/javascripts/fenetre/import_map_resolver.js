/**
 * Fenetre ImportMap Resolver
 * 
 * This script resolves bare specifier imports by dynamically adding missing 
 * entries to the importmap. It specifically handles the 'application' specifier 
 * which may be missing in host applications.
 * 
 * This approach avoids test-specific hacks and works in real applications.
 */

// Function to inject missing mappings into the import map
function injectMissingImportMapEntries() {
  // Ensure we're in a browser environment
  if (typeof window === 'undefined' || typeof document === 'undefined') return;

  // Check if there's an existing import map
  const existingMapScript = document.querySelector('script[type="importmap"]');
  if (!existingMapScript) return;

  try {
    // Parse the existing import map
    const importMap = JSON.parse(existingMapScript.textContent);
    const imports = importMap.imports || {};
    
    // Check if application is already mapped
    if (!imports.application) {
      console.info('Fenetre: Adding missing "application" mapping to import map');
      
      // Use fenetre/application.js as the default for application
      imports.application = imports['fenetre/application'] || '/fenetre/application.js';
      
      // Update the import map
      importMap.imports = imports;
      
      // Create a new script element with the updated import map
      const newMapScript = document.createElement('script');
      newMapScript.type = 'importmap';
      newMapScript.textContent = JSON.stringify(importMap, null, 2);
      
      // Replace the existing import map
      existingMapScript.replaceWith(newMapScript);
    }
  } catch (e) {
    console.error('Fenetre: Error updating import map:', e);
  }
}

// Execute immediately
injectMissingImportMapEntries();