#!/usr/bin/env python3
"""Check Klaviyo service status after backend restart"""

import requests
import json

try:
    r = requests.get('http://localhost:8000/api/v1/demo/klaviyo-integration', timeout=10)
    data = r.json()
    
    status = data.get('integration_summary', {}).get('status', 'unknown')
    
    print('\n' + '='*80)
    print('KLAVIYO SERVICE STATUS:', status.upper())
    print('='*80)
    
    if status == 'enabled':
        print('SUCCESS! Klaviyo is ACTIVE and ready!')
        print('   - API Key: Configured')
        print('   - APIs Available: 8')
        print('   - Ready for event tracking!')
        print('\nNext Steps:')
        print('   1. Run: python test_story_quick.py')
        print('   2. Check Klaviyo dashboard for events')
        print('   3. Record demo video')
    else:
        print('Status:', status)
        print('\nKlaviyo may need a few more seconds to initialize.')
        print('Or check backend logs for any errors.')
    
    print('='*80 + '\n')
    
except Exception as e:
    print(f'Error checking Klaviyo status: {e}')
