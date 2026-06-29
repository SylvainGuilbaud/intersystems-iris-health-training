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
            ns_match = re.search(r'\[([A-Z0-9_\-]+)\]', line)
            if ns_match:
                namespace = ns_match.group(1)
                current_namespace = namespace
                
                if namespace not in namespace_results:
                    namespace_results[namespace] = {
                        "namespace": namespace,
                        "production": "",
                        "status": "unknown",
                        "result": "success",
                        "actions": []
                    }
                
                # Extract information from this line
                if "Production Name:" in line:
                    prod_match = re.search(r'Production Name:\s*([A-Za-z0-9_.]+)', line)
                    if prod_match and prod_match.group(1) != "State":
                        namespace_results[namespace]["production"] = prod_match.group(1)
                
                if "Status:" in line:
                    # Extract status (running, stopped, suspended, need recover, etc.)
                    if "need recover" in line.lower():
                        namespace_results[namespace]["status"] = "need recover"
                    elif "running" in line.lower():
                        namespace_results[namespace]["status"] = "running"
                    elif "stopped" in line.lower():
                        namespace_results[namespace]["status"] = "stopped"
                    elif "suspended" in line.lower():
                        namespace_results[namespace]["status"] = "suspended"
                    elif "error" in line.lower():
                        namespace_results[namespace]["status"] = "error"
                    
                    # Detect message count (messages command)
                    msg_match = re.search(r'(\d+)\s+recent MLLP/HTTP messages', line)
                    if msg_match:
                        namespace_results[namespace]["status"] = f"{msg_match.group(1)} messages"
                    
                    # Add meaningful action messages only (skip pure status repeats)
                    action_msg = line.split("Status:")[-1].strip()
                    if action_msg and ("OK" in action_msg or "Recover" in action_msg or "successfully" in action_msg or "NEED" in action_msg or "messages" in action_msg):
                        if action_msg not in namespace_results[namespace]["actions"]:
                            namespace_results[namespace]["actions"].append(action_msg)
                
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
        return 1
    
    command = sys.argv[1].lower()
    
    if command == "messages":
        spec = sys.argv[2] if len(sys.argv) > 2 else "0"
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
    }
    
    if command in commands:
        return commands[command]()
    else:
        print(f"ERROR: Unknown command '{command}'")
        print(f"Available commands: {', '.join(commands.keys())}")
        return 1


if __name__ == "__main__":
    sys.exit(main())
