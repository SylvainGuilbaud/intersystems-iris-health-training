"""
Utility module for managing IRIS Ensemble productions across multiple namespaces.
Wrapper around ObjectScript adm.utils class methods - calls via shell/iris command.
"""

import subprocess
import sys
import os
import json
import re
from datetime import datetime


class ProductionUtils:
    """Wrapper for Ensemble production utilities - calls ObjectScript methods"""
    
    IRIS_HOME = os.environ.get("IRIS_HOME", "/usr/irissys")
    NAMESPACE = "TRAINING"
    
    @staticmethod
    def run_iris_command(method_name, method_args=""):
        """Execute an ObjectScript method via iris command"""
        try:
            # Build the ObjectScript code to execute  
            iris_code = f"""do $system.OBJ.Load("/code/adm/utils.cls","ck")
d ##class(adm.utils).{method_name}({method_args})
h
"""
            
            # Use stdin approach with filter for logs
            cmd = [
                os.path.join(ProductionUtils.IRIS_HOME, "bin", "iris"),
                "session",
                "IRIS",
                "-U",
                ProductionUtils.NAMESPACE,
            ]
            
            process = subprocess.Popen(
                cmd,
                stdin=subprocess.PIPE,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,  # Combine stderr and stdout
                text=True
            )
            
            stdout, _ = process.communicate(input=iris_code)
            
            # Filter out IRIS logs and keep only ObjectScript output
            # Extract only lines that contain [NAMESPACE] or Status info
            filtered_output = []
            for line in stdout.split('\n'):
                # Skip IRIS startup logs
                if line.startswith('log:') or line.startswith('Node:') or line.startswith('iris-'):
                    continue
                if line.startswith('Allocated') or line.startswith('>>>'):
                    continue
                if line.startswith('<ENDOFFILE>') or line.startswith('<ERRTRAP>'):
                    continue
                # Keep lines with useful content
                if line.strip() and not line.startswith('iris '):
                    filtered_output.append(line)
            
            clean_output = '\n'.join(filtered_output)
            
            # Parse and output JSON to stdout only
            result = ProductionUtils.parse_output(clean_output, "", method_name)
            print(json.dumps(result, indent=2))
            
            return 0 if result["success"] else 1
                
        except Exception as e:
            result = {
                "success": False,
                "command": method_name,
                "error": str(e),
                "timestamp": datetime.now().isoformat()
            }
            print(json.dumps(result, indent=2))
            return 1
    
    @staticmethod
    def parse_output(stdout, stderr, method_name):
        """Parse ObjectScript output and extract namespace results"""
        result = {
            "success": True,
            "command": method_name,
            "timestamp": datetime.now().isoformat(),
            "namespaces": [],
            "summary": {
                "total": 0,
                "success": 0,
                "failed": 0,
                "errors": []
            }
        }
        
        if stderr and stderr.strip():
            result["success"] = False
            result["summary"]["errors"].append(stderr.strip())
        
        # Parse namespace results from output - extract all [NAMESPACE] patterns
        lines = stdout.split('\n')
        namespace_results = {}
        current_namespace = None
        
        for line in lines:
            # Extract namespace from [NAMESPACE] pattern
            ns_match = re.search(r'\[([A-Za-z0-9_\-]+)\]', line)
            if ns_match:
                namespace = ns_match.group(1)
                current_namespace = namespace
                
                if namespace not in namespace_results:
                    namespace_results[namespace] = {
                        "namespace": namespace,
                        "production": "",
                        "status": "unknown",
                        "result": "success",
                        "roles": "",
                        "fullname": "",
                        "actions": []
                    }
                
                # Extract information from this line
                if "Production Name:" in line:
                    prod_match = re.search(r'Production Name:\s*([A-Za-z0-9_.]+)', line)
                    if prod_match and prod_match.group(1) != "State":
                        namespace_results[namespace]["production"] = prod_match.group(1)
                
                if "Status:" in line:
                    # Only inspect the text after "Status:" so keywords in the
                    # [namespace]/[user] bracket (e.g. "interop_operator") are not matched.
                    status_text = line.split("Status:")[-1].lower()
                    # Extract status (running, stopped, suspended, need recover, etc.)
                    if "need recover" in status_text:
                        namespace_results[namespace]["status"] = "need recover"
                    elif "running" in status_text:
                        namespace_results[namespace]["status"] = "running"
                    elif "stopped" in status_text:
                        namespace_results[namespace]["status"] = "stopped"
                    elif "suspended" in status_text:
                        namespace_results[namespace]["status"] = "suspended"
                    elif "error" in status_text:
                        namespace_results[namespace]["status"] = "error"
                    elif "interop" in status_text:
                        namespace_results[namespace]["status"] = "interop"
                    elif "disabled" in status_text:
                        namespace_results[namespace]["status"] = "disabled"
                    elif "enabled" in status_text:
                        namespace_results[namespace]["status"] = "enabled"
                    
                    # Detect message count (messages command)
                    msg_match = re.search(r'(\d+)\s+recent MLLP/HTTP messages', line)
                    if msg_match:
                        namespace_results[namespace]["status"] = f"{msg_match.group(1)} messages"

                    # Detect last audit action (audit command)
                    audit_match = re.search(r'Status:\s*(.+?)\s+last action', line)
                    if audit_match:
                        namespace_results[namespace]["status"] = audit_match.group(1).strip()

                # Detect audit event lines (audit command): "[user] Event: <ts> | <desc>"
                ev_match = re.search(r'Event:\s*(.+)', line)
                if ev_match:
                    event_desc = ev_match.group(1).strip()
                    if event_desc and event_desc not in namespace_results[namespace]["actions"]:
                        namespace_results[namespace]["actions"].append(event_desc)

                # Detect user roles / full name (listusers command)
                roles_match = re.search(r'Roles:\s*(.+)', line)
                if roles_match:
                    namespace_results[namespace]["roles"] = roles_match.group(1).strip()
                fullname_match = re.search(r'FullName:\s*(.+)', line)
                if fullname_match:
                    namespace_results[namespace]["fullname"] = fullname_match.group(1).strip()

                    # Add meaningful action messages only (skip pure status repeats)
                    action_msg = line.split("Status:")[-1].strip()
                    if action_msg and ("OK" in action_msg or "Recover" in action_msg or "successfully" in action_msg or "NEED" in action_msg or "messages" in action_msg or "last action" in action_msg):
                        if action_msg not in namespace_results[namespace]["actions"]:
                            namespace_results[namespace]["actions"].append(action_msg)

                # Operation result lines (no "Status:" prefix), e.g. "[NS] Stopped successfully"
                if "Stopped successfully" in line:
                    namespace_results[namespace]["status"] = "stopped"
                    namespace_results[namespace]["actions"].append("Stopped successfully")
                elif "Already stopped" in line:
                    namespace_results[namespace]["status"] = "stopped"
                    namespace_results[namespace]["actions"].append("Stop not needed (already stopped)")
                elif "Started successfully" in line:
                    namespace_results[namespace]["status"] = "running"
                    namespace_results[namespace]["actions"].append("Started successfully")
                elif "Already running" in line:
                    namespace_results[namespace]["status"] = "running"
                    namespace_results[namespace]["actions"].append("Start not needed (already running)")
                elif "Cleaned successfully" in line:
                    namespace_results[namespace]["status"] = "cleaned"
                    namespace_results[namespace]["actions"].append("Cleaned successfully")
                
                # Detect recover result
                if "Recover executed successfully" in line:
                    namespace_results[namespace]["result"] = "success"
                elif "ERROR during Recover" in line:
                    namespace_results[namespace]["result"] = "failed"
        
        # Convert to list and update summary
        result["namespaces"] = list(namespace_results.values())
        result["summary"]["total"] = len(result["namespaces"])
        
        # Count successes - default all to success if status is ok
        for ns in result["namespaces"]:
            if ns["status"] == "need recover":
                result["summary"]["failed"] += 1
            elif ns["status"] == "error":
                result["summary"]["failed"] += 1
            else:
                result["summary"]["success"] += 1
        
        # If no namespaces found but stdout not empty, list what we got
        if not result["namespaces"] and stdout.strip():
            # For list command, just include raw output
            result["raw_output"] = stdout
        
        return result
    
    @staticmethod
    def list_interop_namespaces():
        """List all application Interop namespaces"""
        return ProductionUtils.run_iris_command("ListInteropNamespaces")
    
    @staticmethod
    def recover_all_productions():
        """Recover all productions that need it"""
        return ProductionUtils.run_iris_command("RecoverAllProductions")
    
    @staticmethod
    def start_all_productions():
        """Start all productions"""
        return ProductionUtils.run_iris_command("StartAllProductions")
    
    @staticmethod
    def stop_all_productions(timeout=0, force=True):
        """Stop all productions"""
        return ProductionUtils.run_iris_command("StopAllProductions")
    
    @staticmethod
    def clean_all_productions(killdata=True):
        """Clean all productions"""
        return ProductionUtils.run_iris_command("CleanAllProductions")
    
    @staticmethod
    def list_recent_mllp_http_messages(min_days=0, max_days=0):
        """Count MLLP/HTTP messages within a day-window (min_days=recent bound, max_days=oldest bound; -1 = unbounded)"""
        return ProductionUtils.run_iris_command("ListRecentMLLPHTTPMessages", f"{int(min_days)},{int(max_days)}")

    @staticmethod
    def list_users_last_audit(n=5):
        """Last n audit events (with descriptions) for each Security.Users user"""
        return ProductionUtils.run_iris_command("ListUsersLastAudit", str(int(n)))

    @staticmethod
    def list_users():
        """List every Security.Users user with enabled state and roles"""
        return ProductionUtils.run_iris_command("ListUsers")

    @staticmethod
    def setup_interop_profiles():
        """Create/update interop security roles (viewer/operator) and their test users"""
        return ProductionUtils.run_iris_command("SetupInteropProfiles")


def main():
    """Main entry point for command-line usage"""
    if len(sys.argv) < 2:
        print("Usage: python utils.py [list|recover|start|stop|clean|messages [spec]]")
        print("\nCommands:")
        print("  list     - List all Interop namespaces")
        print("  recover  - Recover all productions that need it")
        print("  start    - Start all productions")
        print("  stop     - Stop all productions")
        print("  clean    - Clean all productions")
        print("  messages [spec] - Count MLLP/HTTP messages. spec: n (single day), *n (before n days ago), n* (n days ago to today), n-m (m..n days ago); default 0")
        print("  audit [n] - Last n audit events (with descriptions) per Security.Users user; default 5")
        print("  listusers - List all users with their enabled state and roles")
        print("  setup    - Create/update interop security profiles and test users")
        return 1
    
    command = sys.argv[1].lower()

    if command == "audit":
        n = 5
        if len(sys.argv) > 2 and sys.argv[2].strip() != "":
            try:
                n = int(sys.argv[2])
            except ValueError:
                print(f"ERROR: invalid audit count '{sys.argv[2]}' (expected an integer)")
                return 1
        return ProductionUtils.list_users_last_audit(n)
    
    if command == "messages":
        spec = sys.argv[2] if len(sys.argv) > 2 and sys.argv[2].strip() != "" else "0"
        try:
            # Parse window spec:
            #   n    -> single day n days ago (min=n, max=n)
            #   *n   -> before n days ago / older (min=n, max unbounded)
            #   n*   -> from n days ago to today (min=0, max=n)
            #   n-m  -> from m days ago to n days ago, n>=m (min=m, max=n)
            if spec.startswith("*"):
                min_days = int(spec[1:]); max_days = -1
            elif spec.endswith("*"):
                min_days = 0; max_days = int(spec[:-1])
            elif "-" in spec:
                n, m = spec.split("-", 1)
                n, m = int(n), int(m)
                min_days = min(n, m); max_days = max(n, m)
            else:
                min_days = max_days = int(spec)
        except ValueError:
            print(f"ERROR: invalid messages spec '{spec}' (expected n, *n, n*, or n-m)")
            return 1
        return ProductionUtils.list_recent_mllp_http_messages(min_days, max_days)

    commands = {
        "list": ProductionUtils.list_interop_namespaces,
        "recover": ProductionUtils.recover_all_productions,
        "start": ProductionUtils.start_all_productions,
        "stop": ProductionUtils.stop_all_productions,
        "clean": ProductionUtils.clean_all_productions,
        "listusers": ProductionUtils.list_users,
        "setup": ProductionUtils.setup_interop_profiles,
    }
    
    if command in commands:
        return commands[command]()
    else:
        print(f"ERROR: Unknown command '{command}'")
        print(f"Available commands: {', '.join(commands.keys())}")
        return 1


if __name__ == "__main__":
    sys.exit(main())
