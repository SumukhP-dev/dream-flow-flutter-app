"""
Test script for Dream Flow user creation with random values
This script tests user signup functionality directly with Supabase
"""

import os
import json
import random
import string
from supabase import create_client, Client

# Supabase configuration
SUPABASE_URL = "https://dbpvmfglduprtbpaygmo.supabase.co"
SUPABASE_ANON_KEY = "sb_publishable_s1LUGs4Go22G_Z1y7WnQJw_nKcU5pZy"

def generate_random_email():
    """Generate a random email address"""
    domains = ['gmail.com', 'yahoo.com', 'hotmail.com', 'example.com']
    username = ''.join(random.choices(string.ascii_lowercase + string.digits, k=8))
    domain = random.choice(domains)
    return f"test_{username}@{domain}"

def generate_random_password():
    """Generate a random secure password"""
    # Include uppercase, lowercase, digits, and special characters
    chars = string.ascii_letters + string.digits + "!@#$%^&*"
    return ''.join(random.choices(chars, k=12))

def generate_random_name():
    """Generate a random full name"""
    first_names = ['Alex', 'Jordan', 'Taylor', 'Casey', 'Morgan', 'Riley', 'Avery', 'Blake']
    last_names = ['Smith', 'Johnson', 'Williams', 'Brown', 'Jones', 'Garcia', 'Miller', 'Davis']
    
    first = random.choice(first_names)
    last = random.choice(last_names)
    return f"{first} {last}"

def test_user_creation():
    """Test user creation with random values"""
    try:
        # Initialize Supabase client
        supabase: Client = create_client(SUPABASE_URL, SUPABASE_ANON_KEY)
        
        # Generate random user data
        test_email = generate_random_email()
        test_password = generate_random_password()
        test_name = generate_random_name()
        
        print(f"Testing user creation with:")
        print(f"   Email: {test_email}")
        print(f"   Password: {test_password}")
        print(f"   Full Name: {test_name}")
        print()
        
        # Attempt to create user
        print("Creating user account...")
        response = supabase.auth.sign_up({
            "email": test_email,
            "password": test_password,
            "options": {
                "data": {
                    "full_name": test_name
                }
            }
        })
        
        if response.user:
            print("SUCCESS: User created successfully!")
            print(f"   User ID: {response.user.id}")
            print(f"   Email: {response.user.email}")
            print(f"   Email Confirmed: {response.user.email_confirmed_at is not None}")
            print(f"   Created At: {response.user.created_at}")
            
            # Check user metadata
            if response.user.user_metadata:
                print(f"   Full Name: {response.user.user_metadata.get('full_name', 'Not set')}")
            
            return True
        else:
            print("FAILED: User creation failed - no user returned")
            if response.session:
                print(f"   Session created: {response.session.access_token[:20]}...")
            return False
            
    except Exception as e:
        print(f"ERROR: Error during user creation: {str(e)}")
        return False

def test_multiple_users(count=3):
    """Test creating multiple users"""
    print(f"Testing creation of {count} users...\n")
    
    success_count = 0
    for i in range(count):
        print(f"--- Test {i+1}/{count} ---")
        if test_user_creation():
            success_count += 1
        print()
    
    print(f"RESULTS: {success_count}/{count} users created successfully")
    print(f"   Success rate: {(success_count/count)*100:.1f}%")

if __name__ == "__main__":
    print("Dream Flow User Creation Test")
    print("=" * 40)
    
    # Test single user creation
    test_user_creation()
    print("\n" + "="*40)
    
    # Test multiple user creation
    test_multiple_users(3)