const WebSocket = require('ws');
const fs = require('fs');
const path = require('path');

const PORT = 8080;
const wss = new WebSocket.Server({ port: PORT });

// Carregar Dados
const maps = JSON.parse(fs.readFileSync(path.join(__dirname, '../database/maps.json'), 'utf8'));

// Estado Global (Em memória para este exemplo)
const players = new Map();
const droppedItems = new Map(); // id_unico -> { id_unico, item_id, map_id, pos, amount }
const mobs = new Map(); // id_unico -> { uid, mob_id, map_id, pos, stats }
let nextItemId = 1;
let nextMobId = 1;

console.log(`[RF-Server] Servidor rodando na porta ${PORT}`);

wss.on('connection', (ws) => {
    let playerId = null;

    ws.on('message', (message) => {
        const data = JSON.parse(message);

        switch (data.type) {
            case 'login':
                playerId = data.name;
                players.set(playerId, {
                    id: playerId,
                    name: data.name,
                    map_id: 'novus_hq',
                    pos: { x: 0, y: 0, z: 0 },
                    speed_val: 1.0,
                    ws: ws
                });
                console.log(`[Login] ${playerId} entrou no mundo.`);
                sendToPlayer(playerId, { type: 'welcome', map_id: 'novus_hq', pos: { x: 0, y: 0, z: 0 } });
                broadcastMapState('novus_hq');
                break;

            case 'move':
                if (players.has(playerId)) {
                    const data_move = data;
                    players.get(playerId).is_running = data.is_running || false;
                    handleMove(playerId, data_move.input_dir, data_move.delta);
                }
                break;

            case 'request_speed':
                // Sincroniza a velocidade do jogador vinda do Godot
                if (players.has(playerId)) {
                    players.get(playerId).speed_val = data.value;
                }
                break;

            case 'admin_map':
                if (players.has(playerId) && maps[data.target_map]) {
                    const p = players.get(playerId);
                    const oldMap = p.map_id;
                    p.map_id = data.target_map;
                    p.pos = { ...maps[data.target_map].spawn };
                    sendToPlayer(playerId, { type: 'map_change', map_id: p.map_id, pos: p.pos });
                    broadcastMapState(oldMap);
                    broadcastMapState(p.map_id);
                }
                break;

            case 'admin_pos':
                if (players.has(playerId)) {
                    const p = players.get(playerId);
                    p.pos.x = data.x;
                    p.pos.z = data.z;
                    sendToPlayer(playerId, { type: 'pos_update', pos: p.pos, map_id: p.map_id });
                }
                break;

            case 'item_drop':
                if (players.has(playerId)) {
                    const p = players.get(playerId);
                    const newItem = {
                        uid: nextItemId++,
                        item_id: data.item_id,
                        map_id: p.map_id,
                        pos: data.pos,
                        amount: data.amount || 1
                    };
                    droppedItems.set(newItem.uid, newItem);
                    broadcastToMap(p.map_id, { type: 'item_drop', item: newItem });
                }
                break;

            case 'item_pickup':
                if (players.has(playerId)) {
                    const p = players.get(playerId);
                    const item = droppedItems.get(data.uid);
                    if (item && item.map_id === p.map_id) {
                        // VALIDAÇÃO: Remove imediatamente do servidor para evitar coleta dupla
                        droppedItems.delete(data.uid);
                        broadcastToMap(p.map_id, { type: 'item_remove', uid: data.uid });
                        // Confirma para o jogador que ele pegou o item
                        sendToPlayer(playerId, { type: 'pickup_success', item: item });
                        console.log(`[Pickup] ${p.name} coletou item ${item.item_id}`);
                    }
                }
                break;

            case 'admin_spawn_mob':
                if (players.has(playerId)) {
                    const p = players.get(playerId);
                    const newMob = {
                        uid: nextMobId++,
                        mob_id: data.mob_id,
                        map_id: p.map_id,
                        pos: data.pos,
                    };
                    mobs.set(newMob.uid, newMob);
                    broadcastToMap(p.map_id, { type: 'mob_spawn', mob: newMob });
                    console.log(`[Admin] ${p.name} spawnou mob ${data.mob_id} no mapa ${p.map_id}`);
                }
                break;

            case 'mob_die':
                if (players.has(playerId)) {
                    const p = players.get(playerId);
                    const mobUid = parseInt(data.uid);
                    if (mobs.has(mobUid)) {
                        mobs.delete(mobUid);
                        broadcastToMap(p.map_id, { type: 'mob_remove', uid: mobUid });
                        console.log(`[Mob] Mob ${mobUid} morreu no mapa ${p.map_id}`);
                    }
                }
                break;

            case 'entity_damage':
                if (players.has(playerId)) {
                    const p = players.get(playerId);
                    // Retransmite o dano para todos no mapa (para verem HP e números flutuantes)
                    broadcastToMap(p.map_id, {
                        type: 'entity_damage',
                        victim_uid: data.victim_uid,
                        victim_type: data.victim_type, // 'mob' ou 'player'
                        damage: data.damage,
                        attacker_id: p.name
                    });
                }
                break;
        }
    });

    ws.on('close', () => {
        if (playerId) {
            const mapId = players.get(playerId).map_id;
            players.delete(playerId);
            broadcastMapState(mapId);
            console.log(`[Logout] ${playerId} saiu.`);
        }
    });
});

function handleMove(id, inputDir, delta) {
    const p = players.get(id);
    if (!p) return;

    const map = maps[p.map_id];
    
    // CÁLCULO DE VELOCIDADE (Integrado com seu sistema 1.0 - 7.0)
    // Cálculo do multiplicador (+1% por cada 0.1 acima de 1.0)
    const bonusPercent = Math.max(0, (p.speed_val - 1.0) * 10);
    const multiplier = 1.0 + (bonusPercent / 100.0);
    
    // Velocidade Base: 12.0 se estiver correndo, 5.0 se estiver andando
    const baseSpeed = p.is_running ? 12.0 : 5.0;
    const move_speed = baseSpeed * multiplier;

    // Nova posição teórica
    let newX = p.pos.x + (inputDir.x * move_speed * delta);
    let newZ = p.pos.z + (inputDir.z * move_speed * delta);

    // VALIDAÇÃO DE LIMITES (SERVER-SIDE)
    if (newX < map.limits.x_min) newX = map.limits.x_min;
    if (newX > map.limits.x_max) newX = map.limits.x_max;
    if (newZ < map.limits.z_min) newZ = map.limits.z_min;
    if (newZ > map.limits.z_max) newZ = map.limits.z_max;

    p.pos.x = newX;
    p.pos.z = newZ;

    // CHECAR PORTAIS
    checkPortals(p);

    // Envia de volta a posição validada para o jogador
    sendToPlayer(id, { type: 'pos_update', pos: p.pos, map_id: p.map_id });
    
    // BROADCAST: Avisa todos os outros no mapa sobre o movimento
    broadcastMapState(p.map_id);
}

function checkPortals(p) {
    const map = maps[p.map_id];
    for (const portal of map.portals) {
        const dist = Math.sqrt(
            Math.pow(p.pos.x - portal.pos.x, 2) +
            Math.pow(p.pos.z - portal.pos.z, 2)
        );

        if (dist <= portal.range) {
            console.log(`[Portal] ${p.id} teleportando para ${portal.target_map}`);
            const oldMap = p.map_id;
            p.map_id = portal.target_map;
            p.pos = { ...portal.spawn_at };
            
            sendToPlayer(p.id, { type: 'map_change', map_id: p.map_id, pos: p.pos });
            broadcastMapState(oldMap);
            broadcastMapState(p.map_id);
            break;
        }
    }
}

function sendToPlayer(id, data) {
    const p = players.get(id);
    if (p && p.ws.readyState === WebSocket.OPEN) {
        p.ws.send(JSON.stringify(data));
    }
}

function broadcastMapState(mapId) {
    const mapPlayers = Array.from(players.values())
        .filter(p => p.map_id === mapId)
        .map(p => ({ id: p.id, name: p.name, pos: p.pos }));

    const mapItems = Array.from(droppedItems.values())
        .filter(i => i.map_id === mapId);

    const mapMobs = Array.from(mobs.values())
        .filter(m => m.map_id === mapId);

    players.forEach(p => {
        if (p.map_id === mapId) {
            sendToPlayer(p.id, { 
                type: 'map_sync', 
                players: mapPlayers,
                items: mapItems,
                mobs: mapMobs
            });
        }
    });
}

function broadcastToMap(mapId, data) {
    players.forEach(p => {
        if (p.map_id === mapId) {
            sendToPlayer(p.id, data);
        }
    });
}
