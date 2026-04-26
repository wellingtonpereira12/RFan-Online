import urllib.request
import urllib.parse
import json
import time
import os
import sys
import argparse

API_KEY = "msy_n23GAkqOq8BKJLLLXzRleHS1UjtmgYmAhG6G"
BASE_URL = "https://api.meshy.ai/openapi/v2/text-to-3d"

class MeshyAgent:
    def __init__(self, api_key):
        self.api_key = api_key
        self.headers = {
            "Authorization": f"Bearer {self.api_key}",
            "Content-Type": "application/json"
        }

    def _request(self, method, url, data=None):
        req = urllib.request.Request(url, headers=self.headers, method=method)
        if data:
            req.data = json.dumps(data).encode('utf-8')
        
        try:
            with urllib.request.urlopen(req) as f:
                return json.loads(f.read().decode('utf-8'))
        except urllib.error.HTTPError as e:
            print(f"HTTP Error: {e.code} - {e.read().decode('utf-8')}")
            raise

    def create_preview(self, prompt, model_type="lowpoly"):
        print(f"--- FASE PREVIEW (Econômica) ---")
        print(f"Prompt: '{prompt}'")
        payload = {
            "mode": "preview",
            "prompt": prompt,
            "art_style": "realistic",
            "model_type": model_type
        }
        res = self._request("POST", BASE_URL, payload)
        return res["result"]

    def create_refine(self, preview_id, hd=False, pbr=True):
        print(f"--- FASE REFINEMENT (Custo Elevado) ---")
        print(f"ID do Preview: {preview_id}")
        print(f"Config: HD={hd}, PBR={pbr}")
        payload = {
            "mode": "refine",
            "preview_task_id": preview_id,
            "enable_pbr": pbr,
            "hd_texture": hd
        }
        res = self._request("POST", BASE_URL, payload)
        return res["result"]

    def get_task(self, task_id):
        return self._request("GET", f"{BASE_URL}/{task_id}")

    def wait_for_task(self, task_id, interval=10):
        while True:
            data = self.get_task(task_id)
            status = data["status"]
            progress = data.get("progress", 0)
            print(f"  > Status: {status} ({progress}%)", flush=True)
            
            if status == "SUCCEEDED":
                return data
            elif status in ["FAILED", "CANCELED"]:
                err = data.get('task_error', {}).get('message', 'Unknown error')
                raise Exception(f"Task failed: {err}")
            
            time.sleep(interval)

    def download(self, task_id, output_path):
        data = self.get_task(task_id)
        url = data["model_urls"].get("glb")
        if not url:
            # Tentar pegar do thumbnail se for apenas preview
            url = data.get("thumbnail_url")
            print("Aviso: Baixando apenas o Thumbnail/Preview (sem texturas PBR).")
        
        print(f"Baixando arquivo para {output_path}...")
        os.makedirs(os.path.dirname(output_path), exist_ok=True)
        urllib.request.urlretrieve(url, output_path)
        print("Download concluído.")

def main():
    parser = argparse.ArgumentParser(description="Meshy Agent Econômico")
    subparsers = parser.add_subparsers(dest="command", help="Comandos")

    # Comando Preview (Barato)
    p_gen = subparsers.add_parser("preview", help="Gera apenas a geometria (Econômico)")
    p_gen.add_argument("prompt", help="Prompt do objeto")
    p_gen.add_argument("--lowpoly", action="store_true", default=True)

    # Comando Refine (Caro)
    p_ref = subparsers.add_parser("refine", help="Adiciona texturas de alta qualidade (Caro)")
    p_ref.add_argument("task_id", help="ID do preview que você gostou")
    p_ref.add_argument("--hd", action="store_true", help="Ativar Texturas 4K (Mais caro)")
    p_ref.add_argument("--no-pbr", action="store_true", help="Desativar materiais realistas (Mais barato)")
    p_ref.add_argument("-o", "--output", required=True, help="Nome do arquivo final")

    # Comando Full (O que tínhamos antes)
    p_full = subparsers.add_parser("full", help="Executa Preview + Refine automaticamente")
    p_full.add_argument("prompt")
    p_full.add_argument("-o", "--output", required=True)

    args = parser.parse_args()
    agent = MeshyAgent(API_KEY)

    try:
        if args.command == "preview":
            task_id = agent.create_preview(args.prompt)
            data = agent.wait_for_task(task_id)
            print(f"\n[OK] Preview finalizado!")
            print(f"ID para refinamento: {task_id}")
            print(f"Thumbnail: {data.get('thumbnail_url')}")
            print("\nSe gostar do formato, rode: python scripts/meshy_agent.py refine " + task_id + " -o nome.glb")

        elif args.command == "refine":
            ref_id = agent.create_refine(args.task_id, hd=args.hd, pbr=not args.no_pbr)
            agent.wait_for_task(ref_id)
            agent.download(ref_id, "assets/models/" + args.output)
            print(f"\n[SUCESSO] Modelo refinado salvo em: assets/models/{args.output}")

        elif args.command == "full":
            # Preview
            p_id = agent.create_preview(args.prompt)
            agent.wait_for_task(p_id)
            # Refine (Padrão econômico: No HD)
            r_id = agent.create_refine(p_id, hd=False, pbr=True)
            agent.wait_for_task(r_id)
            agent.download(r_id, "assets/models/" + args.output)
            print(f"\n[SUCESSO] Modelo completo salvo em: assets/models/{args.output}")

    except Exception as e:
        print(f"\n[ERRO] {e}")

if __name__ == "__main__":
    main()
