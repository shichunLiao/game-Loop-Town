"""Story 1.1 (Jerry, Ling, the harvest festival): rewrite player-facing text and
reorder the main route to art museum, theater, clock tower, then the well.

Run after build_exploration_v8.py. Room, flag, gate, NPC and item ids stay the
same; only gate requirements, two relic grants and the main quest list change.
"""
from pathlib import Path
import json

ROOT=Path(__file__).resolve().parents[2]
DATA=ROOT/'data/exploration'

# Room names also appear as exit labels and inside "A → B" connector names.
ROOM_NAMES={
    '蜡像巷':'美术馆前街',
    '蜡像馆 · 熔炉':'美术馆 · 无尽走廊',
    '七镜地下室':'七镜画室',
    '枯井 · 风向相同的树':'枯井 · 警戒线',
    '最终循环 · 火海':'丰收祭之夜',
    '第零次 · 火车站':'清晨 · 小镇车站',
    '蜡面陈列店 · 室内':'石膏像陈列店 · 室内',
    '莫里斯的工棚 · 室内':'梅·莫里的画室 · 室内',
    '余烬民居 · 室内':'丰收祭夜的民居 · 室内',
}

STORY={
    # Buildings, connectors and landmarks.
    '蜡面陈列店':'石膏像陈列店',
    '莫里斯的工棚':'梅·莫里的画室',
    '烛泪桥':'颜料桥',
    '余烬民居':'丰收祭夜的民居',
    '炭化广场':'火把广场',
    '余烬高架':'灯笼高架',
    '熔炉检修口':'画廊检修口',
    '余烬拱廊':'火把拱廊',
    '熔炉底座':'画廊底座',
    # Residents. Roles double as gate guide names, so both change together.
    '送蜡工':'送画工',
    '熔炉守灯人':'美术馆守灯人',
    '订单抄写员':'画册抄写员',
    '火光中的旧影':'火把下的旧影',
    '抱着布包的女人':'姑姑的老邻居',
    '我认得这顶帽子……钟声一响，我又想不起来了。':'丰收祭那晚，镇上的火把也是这样一盏一盏点起来的……钟声一响，我又想不起来了。',
    '我在等一个人。他每一次都说，还有最后一趟。':'你是她的侄子吧？葬礼的事，节哀。她一直留着你小时候的画。',
    '你的右脸……不，对不起。我又说错了。':'你的右脸……不，对不起。我不该一直盯着看。',
    '水桶是空的，我还是得把它送过去。西边的楼梯通向蜡像巷。':'施工队从枯井里挖出了东西，警察拉了线。西边的楼梯通向美术馆前街。',
    '楼梯一层一层地走。你从前背着人，也这样走过。':'楼梯一层一层地走。你小时候总跟着那个扎双马尾的女孩跑上跑下。',
    '红线绷得太紧了。大剪刀能剪开它们，也能挡开那些坏掉的木偶。':'红线绷得太紧了。美工刀能割断它们，也能挡开那些坏掉的木偶。',
    '后台那只双马尾布偶，眼睛一直完好。':'后台那只双马尾布偶，是道具师沃伊德帮一个男孩缝好的。眼睛一直完好。',
    '七面镜子，七个方向。被烧掉的书页里，还压着一枚金属牌。':'七面镜子，七个方向。旧报纸堆里，还压着一张没人领回的寻人启事。',
    '最后一张票不卖。那是给一个不该被忘记的人留的。':'丰收祭那晚的演出，有两个孩子一直没有来。',
    '有一班车，一直在等一个肯摘下帽子的人。':'早班车七点开。离开，或者留下来把事情弄清楚，都可以。',
    '三枚印记才开得了钟楼。发条外庭的楼梯通往上层，不要跳过台阶。':'两枚印记就开得了钟楼。发条外庭的楼梯通往上层，不要跳过台阶。',
    # Enemies, boss, abilities and weapons.
    '踉跄蜡像':'僵硬的雕像',
    '烛泪喷吐者':'泼墨画像',
    '火中的居民':'火把下的人影',
    '莫里斯 · 第 247 张脸':'梅·莫里 · 美术馆的主人',
    '蜡像馆':'美术馆',
    '笔记本挥击':'调色刀挥击',
    '剪刃连击 / 剪刃突进':'美工刀连击 / 美工刀突进',
    '余烬冲刺':'解离冲刺',
    '墨页短刃':'调色刀',
    '裁断大剪刀':'美工刀',
    '井火钩刃':'井藤钩刃',
    # Main quests.
    '第一张纸页':'刑警的传唤',
    '调查镇口路灯左侧的信，再沿西环街进入蜡像馆。':'调查镇口路灯左侧的传唤单，再沿西环街前往美术馆，拜访梅·莫里老师。',
    '蜡像馆的剪刃':'美术馆的美工刀',
    '沿西环街、蜡像巷进入蜡像馆，拾取大剪刀。':'沿西环街、美术馆前街进入美术馆，拾取美工刀。',
    '熔炉前的阻拦':'恩师扭曲的脸',
    '击败蜡像馆深处的莫里斯。J 连击，H 恢复。':'击败美术馆走廊深处的梅·莫里。J 连击，H 恢复。',
    '继续登塔，在顶层触碰那一夜的记忆。':'继续登塔，在顶层触碰丰收祭那一夜的记忆。',
    '火光之后重访井底，听完被打断的话。':'穿过丰收祭之夜重访井底，想起那天真正发生的事。',
    '放下帽子':'守钟人的选择',
    '前往影子屋顶，选择摘下帽子，再沿右侧道路前往车站。':'前往停钟之处面对守钟人，做出选择，再沿右侧道路前往车站。',
    # Side quests and gates.
    '留给帽子的位置':'窗边的一束花',
    '进入莫里斯的工棚，寻找「擦拭过的工具」，再回来交谈。':'进入梅·莫里的画室，寻找「擦拭过的工具」，再回来交谈。',
    '蜡像馆地窖门':'美术馆地窖门',
    '蜡像馆、剧院、井底各有一枚印记。收齐三枚后回广场，按 E 转动大门的钟钥。':'美术馆与剧院各有一枚印记。收齐两枚后回广场，按 E 转动大门的钟钥。',
    '先击败莫里斯，再拿大剪刀剪开门轴蜡封，按 E 打开地窖门。':'先击败梅·莫里，再用美工刀割开门轴上的封条，按 E 打开地窖门。',
    '井底左侧有排水拉杆。先拉闸，再从排水隧道返回蜡像地下室。':'井底左侧有排水拉杆。先拉闸，再从排水隧道返回美术馆地下画室。',
    '大剪刀在蜡像馆。拿到后可切开门锁旁的红线，按 E 推开侧门。':'美工刀在美术馆。拿到后可割断门锁旁的红线，按 E 推开侧门。',
    '后台有一个完整布偶，带回它的印记。蜡像与剧院两枚印记可以释放东街的道路绞盘。':'后台有一个完整的布偶，带回它的印记。美术馆与剧院两枚印记可以释放东街的道路绞盘。',
    '先听完井底的话，在影子面前摘下帽子，再推开通向车站的门。':'先想起井边发生的事，在守钟人面前做出选择，再推开通向车站的门。',
    '先在熔炉战场击败莫里斯，镜室的机械锁才会松开。':'先在无尽走廊击败梅·莫里，镜室的机械锁才会松开。',
    '上方档案室需要蜡像印记和二段跳':'上方档案室需要美术馆印记和二段跳',
    '门缝被红线封住，需要大剪刀':'门缝被红线封住，需要美工刀',
    '先带回蜡像与剧院的两枚印记':'先在钟楼顶回应守钟人',
    '火海中的旧井房':'丰收祭夜的旧井房',
    '钟楼门上还缺三枚记忆印记':'钟楼门上还缺两枚记忆印记',
    '先触碰发条旁的记忆':'先回应钟楼顶的守钟人',
    '触碰顶层记忆后，钟顶通往旧日街道的门才会回应。':'在钟楼顶回应守钟人之后，通往丰收祭之夜的门才会打开。',
    # Interactable titles.
    '一封没有署名的信':'刑警留下的传唤单',
    '大剪刀':'美工刀',
    '不会消失的脸':'盯着你的画像',
    '永远未完成的订单':'永远画不完的画',
    '磨平的消防志愿队牌':'旧报纸上的寻人启事',
    '最后的戏票':'两张丰收祭海报',
    '另一圈路':'放学的路',
    '夏令营合照':'美术室的合照',
    '那句话的后半截':'那天真正发生的事',
    '七年前 · 那一夜':'丰收祭 · 那一夜',
    '我帮你拧发条':'面对守钟人',
    '摘下帽子':'守钟人留下的帽子',
    '举起武器':'让钟声倒带',
    '最后一趟':'最后一眼',
    '七个自己':'分出去的自己',
    '第零次循环':'清晨',
    '门后的水桶':'门后的灯笼',
    '蜡像订单':'并排的两幅画',
    '七年前的火光':'丰收祭的钟声',
    '完整的记忆':'井边的那一天',
    # Memories and clue texts.
    '请找到小铃，带她回家。':'姑姑的葬礼之后，刑警找上门：施工队在枯井下挖出一具遗骸，已确认是玲。\n请你明天到警局配合调查。',
    '如果我停下制作，蜡像就会开始流血。':'画里的人都在看你。只要停下脚步，它们就开始笑。',
    '蜡滴绕开了最中间的空位。这里像是一直缺着最后一件作品。':'石膏像绕开了最中间的空位。这里像是一直缺着最后一件作品。',
    '雕刻刀的握柄被磨得很亮。蜡屑里混着一小片烧焦的布。':'雕刻刀的握柄被磨得很亮。石膏屑里混着一小片蓝色的裙布。',
    '钥匙下压着一张旅客登记纸。姓名被涂黑，只留下一个帽子的简笔画。':'钥匙下压着一张旅客登记纸。姓名被涂黑，旁边是一张小孩画的自画像，右脸涂成了黑色。',
    '金属牌上没有姓名。\n不是她。还有另一个走进火场的人，被压在这段记忆里。':'失踪：玲，十岁。丰收祭当晚未归。\n启事下压着一行铅笔字：那天下午，她拿走了两张演出海报。',
    '本券可作为『不被忘记』的凭证。票边卷曲，那不是血迹，是焦痕。':'丰收祭夜场演出。两张海报叠在一起，背面写着：给杰利。\n有一张，从来没有被撕开过。',
    '本券可作为『不被忘记』的凭证。':'丰收祭夜场演出。海报背面写着：给杰利。',
    '你曾经从这里背着人跑过。现在只剩窗里的光。':'放学后，你和她从这里一路跑去美术室。现在只剩窗里的光。',
    '七年，七个部分。你不需要抹去它们，才能离开这里。':'梅、沃伊德、守钟人、弗瑞、玲……它们都是你分出去的一部分。你不需要抹去它们，才能离开这里。',
    '门后留着半只烧裂的木桶。桶把上缠着一块灰色布条。':'门后靠着半盏丰收祭的灯笼。提手上缠着一块灰色布条。',
    '候车室的长椅被擦得很干净。窗边留着一个放帽子的位置。':'候车室的长椅被擦得很干净。窗边放着一束还没有送出去的花。',
    '全镇居民尺寸蜡像一套。数量：247。订购人的名字被涂黑。':'画室墙上并排挂着两幅孩子的画：一幅安静、灰暗，一幅明亮、热闹。署名是杰利和玲。',
    '最后一天，他说要玩一个游戏。':'照片里，扎双马尾的女孩在笑，旁边的男孩用手挡住了右脸。',
    '他冲进去。一趟，又一趟。最后只听见：『来不及了——』':'火把里人影晃动。弗瑞在笑，玲的父母在人群里喊她的名字。钟声响起，你像在看别人的事。',
    '来不及了，再进去就出不来了——把他拉出来！':'她挡在你前面，被推倒，头撞在井口。弗瑞他们逼你一起把她抬起来……你看见她的手，好像还在动。',
    # Longer room texts.
    '西环的上行楼梯通向蜡像馆；东环的上层通向剧院，下层通向枯井。三枚印记能开启钟楼。地图只标记路线，所有道路都需实际走过。':
        '西环的上行楼梯通向美术馆；东环的上层通向剧院，下层通向枯井。两枚印记能开启钟楼。地图只标记路线，所有道路都需实际走过。',
    '记住每一张脸。\n蜡像馆在巷子的西端。熔蜡池每隔一段时间喷涌，观察亮起的预兆。':
        '画里的每一张脸都记得你。\n美术馆在街的西端。颜料池每隔一段时间喷涌，观察亮起的预兆。',
    '获得大剪刀：J 的近战范围与伤害提升；K 剪刃突进。W / S + J 可向上 / 下攻击。击败熔炉前的莫里斯，打开镜室通路。':
        '获得美工刀：J 的近战范围与伤害提升；K 美工刀突进。W / S + J 可向上 / 下攻击。击败走廊尽头的梅·莫里，打开镜室通路。',
    '全镇居民尺寸蜡像一套。数量：247。\n地下室入口藏在熔炉左侧，那里留下了七面镜子。':
        '画室墙上并排挂着两幅孩子的画。\n地下画室的入口藏在走廊左侧，那里留下了七面镜子。',
    '七镜的正确刻度依次为：\n2 · 3 · 4 · 1 · 2 · 4 · 3\n每按一次 E 转动一格。所有角度吻合时，光会沿着七面镜子传向未完成的蜡块。':
        '七镜的正确刻度依次为：\n2 · 3 · 4 · 1 · 2 · 4 · 3\n每按一次 E 转动一格。所有角度吻合时，光会沿着七面镜子传向那幅没有画完的画。',
    '所有破旧的布偶中，只有这一只没有裂痕。\n获得女孩布偶、剧院印记、二段跳与藤蔓攀爬。\n新的能力让旧地图的上层支路变得可达。':
        '所有破旧的布偶中，只有这一只没有裂痕。那是你小时候亲手做、想送给玲的玩偶。\n获得玲的布偶、剧院印记、二段跳、藤蔓攀爬与冲刺（Shift）。\n新的能力让旧地图的上层支路变得可达。',
    '最后一天，他说要玩一个游戏。获得井底印记与冲刺（Shift）。黑泥开始上涌！抓住藤蔓返回，或拉开左侧排水闸，从近路离开。':
        '照片里，扎双马尾的女孩在笑，旁边的男孩用手挡住了右脸。获得井底印记。黑泥开始上涌！抓住藤蔓返回，或拉开左侧排水闸，从近路离开。',
    '井底与蜡像馆地下室重新连通。':'井底与美术馆地下画室重新连通。',
    '来不及了，再进去就出不来了——把他拉出来！\n这一次，你终于听完了那句话。':
        '她挡在你前面，被推倒，头撞在井口。弗瑞他们逼你一起把她抬起来……你看见她的手，好像还在动。\n这一次，你终于想起来了。',
    '他冲进去。一趟，又一趟。\n最后一趟是为了小铃。他把她从井口拉上来，用外套裹住，背起来。\n横梁砸中右脸。意识断开前，他只听见：『来不及了——』':
        '丰收祭的夜晚。火把里人影晃动，弗瑞在笑，玲的父母在人群里喊她的名字。\n钟声响起。你站在人群里，神情呆滞，像在看别人的事。\n从那一夜开始，你把她忘了。',
    '同一座小镇，终于显出了那一夜的颜色。\n前往停钟之处，或者再回一次枯井，找回那句话的后半截。':
        '同一座小镇，终于显出了丰收祭那一夜的颜色。\n前往停钟之处见守钟人，或者再回一次枯井，想起那天真正发生的事。',
}
STORY.update(ROOM_NAMES)


def rewrite(value,used):
    if isinstance(value,dict):
        return {k:rewrite(v,used) for k,v in value.items()}
    if isinstance(value,list):
        return [rewrite(v,used) for v in value]
    if not isinstance(value,str):
        return value
    if value in STORY:
        used.add(value)
        return STORY[value]
    if ' → ' in value:
        parts=value.split(' → ')
        for p in parts:
            if p in ROOM_NAMES:
                used.add(p)
        return ' → '.join(ROOM_NAMES.get(p,p) for p in parts)
    return value


KEEPER='keeper_truth'
# Story 1.1 order: art museum, theater, clock tower (keeper's choice), well last.
GATE_REQUIRES={
    'town_hub--clock_exterior':['wax_seal','theater_seal'],
    'ring_east--dry_well':[KEEPER],
    'clock_top--fire_town':[KEEPER],
    'fire_town--dry_well':[KEEPER],
}
MAIN_ORDER=['main_letter','main_scissors','main_boss_morris','main_wax_seal','main_theater_seal',
            'main_warden_note','main_clock_memory','main_zero_loop','main_well_seal','main_true_memory']


def reorder_v9(data):
    world,quests,actors=data['world'],data['quests'],data['actors']
    for gate_id,requires in GATE_REQUIRES.items():
        quests['gates'][gate_id]['requires']=list(requires)
    quests['gates']['ring_east--dry_well']['text']='井口拉着警戒线。在钟楼顶回应守钟人之后，再从这里走向枯井。'
    quests['gates']['back_stage--ring_east']['text']='后台有一个完整的布偶，带回它的印记，再从后台回到东街。'
    for r in world['rooms'].values():
        for e in r['exits']:
            if e.get('gate_id') in GATE_REQUIRES:
                e['requires']=list(GATE_REQUIRES[e['gate_id']])
        # Dash comes with the doll, so the tower is climbed with the same moves as before.
        for o in r['objects']:
            if o.get('item')=='theater_seal':
                o['grants']=o['grants']+['dash']
            elif o.get('item')=='well_seal':
                o['grants']=[g for g in o['grants'] if g!='dash']
    for skill in actors['skills']:
        if skill['id']=='dash':
            skill['stage']='剧院后台'
    main={q['id']:q for q in quests['main']}
    main['main_warden_note']['text']='两枚印记齐全，回广场启动钟门，沿实际楼梯登塔，在中层调查守钟人的笔记。'
    main['main_zero_loop'].update(flag=KEEPER,title='守钟人的选择',
        text='在钟楼顶回应摘下帽子的守钟人：听他的话离开，或者去井边找回真相。',room='clock_top',pos=[880,1140])
    main['main_well_seal']['text']='穿过丰收祭之夜来到枯井，带布偶打开井口检修门。沿藤蔓下井，取得合照后立刻撤离。'
    main['main_true_memory'].update(title='井底的真相',text='回到井底深处，想起那天真正发生的事。')
    quests['main']=[main[i] for i in MAIN_ORDER]


def theater_boss_v9(data):
    """Void waits at back-stage center; the doll is his until he falls."""
    r=data['world']['rooms']['back_stage']
    r['boss']=dict(type='void',pos=[1760,940],arena=[960,2120],hp=760,floor=940)
    for o in r['objects']:
        if o.get('item')=='theater_seal':
            o['requires']=['boss_void']
    # The seamstress steps out of the stage the curtains close around.
    for n in r['npcs']:
        if n['pos'][0]>960:
            n['pos'][0]=520
    main={q['id']:q for q in data['quests']['main']}
    main['main_theater_seal']['text']='从东街打开剧院侧门，剪断三组红线，再打开后台防火门。击败道具师沃伊德，取回那只完整的布偶。'


def keeper_chase_v9(data):
    """The climb becomes a chase: two perfect versions on the wide floors, the keeper above."""
    rooms=data['world']['rooms']
    rooms['clock_tower']['keeper_chase']=dict(interval=40,echoes=[
        dict(type='morris',label='梅·莫里',flag='echo_morris',pos=[820,3600],arena=[230,1240],hp=560,floor=3600),
        dict(type='void',label='沃伊德',flag='echo_void',pos=[760,2112],arena=[230,1240],hp=520,floor=2112),
    ])
    rooms['clock_top']['keeper_figure']=[790,1140]
    main={q['id']:q for q in data['quests']['main']}
    main['main_warden_note']['text']='两枚印记齐全，回广场启动钟门。沿楼梯追赶守钟人，在中层调查他留下的笔记。'
    main['main_clock_memory']['text']='击败完美版本的梅·莫里与沃伊德，在顶层触碰丰收祭那一夜的记忆。'


def well_ending_v9(data):
    """Fury pushes Jerry in at the well mouth; Ling waits at the bottom instead of the flood."""
    rooms,quests=data['world']['rooms'],data['quests']
    dry,well=rooms['dry_well'],rooms['well_interior']
    dry['fury_scene']=dict(trigger=3040,well=[3330,1240],arena=[2560,3480],behind=330,
        target='well_interior',arrival=[700,2837])
    hatch='检修门从里面锁死了。井口在下面的空地上，拉着警戒线。'
    for r in (dry,well):
        for e in r['exits']:
            if e.get('gate_id')=='dry_well--well_interior':
                e.update(requires=['fury_done'],hint=hatch)
    quests['gates']['dry_well--well_interior'].update(requires=['fury_done'],text=hatch)
    for o in dry['objects']:
        if o['kind']=='sign':
            o['text']='井口已经被施工队挖开了，旁边拉着警戒线。刑警已经撤了。\n藤蔓旁按 W / S 攀爬；S + Space 可穿下脚边的平台。'
    well['boss']=dict(type='ling',pos=[1320,2840],arena=[215,1660],hp=1800,floor=2840,top=2150,
        start=[700,2837],requires=['fury_done'],
        knots=[[620,2790],[760,2660],[1120,2420],[520,2540],[1240,2300],[420,2180]])
    well['vines'].append([900,2250,70,590])
    well['ling_figure']=[1650,2840]
    well['enemies']=[e for e in well['enemies'] if e['pos'][1]<2200]
    for o in well['objects']:
        if o.get('item')=='well_seal':
            o.update(appears_after=['boss_ling'],text='照片里，扎双马尾的女孩在笑，旁边的男孩用手挡住了右脸。')
        elif o['kind']=='true_memory':
            o.update(pos=[1620,2840],appears_after=['boss_ling'],title='我找到你了',
                text='站在那里的是玲。真正的她。双马尾，白衬衫，蓝裙子。干净，安静。\n她蹲在枯井的角落里，头埋得很低，很害怕的样子。\n\n「我找到你了。」\n\n她挡在你前面，被推倒，头撞在井口。弗瑞他们逼你一起把她抬起来……你看见她的手，好像还在动。\n这一次，你终于想起来了。')
    main={q['id']:q for q in quests['main']}
    main['main_well_seal'].update(flag='fury_done',title='枯井边的警戒线',
        text='穿过丰收祭之夜来到枯井，走到警戒线旁的井口。',room='dry_well',pos=[3330,1240])
    main['main_true_memory'].update(title='我找到你了',text='走到井底的角落，那里蹲着真正的玲。',pos=[1620,2840])
    quests['main'].insert(quests['main'].index(main['main_true_memory']),
        dict(id='main_ling',flag='boss_ling',title='井底的玲',
            text='砍断发光的藤结，趁泥浆退去、藤蔓松开时攻击她的身体。别让泥浆没过胸口。',
            room='well_interior',pos=[1320,2840]))


def art_v9(data):
    """Demo 9: Codex drew the story 1.1 cast; the theater's seat puppets use their own sprite."""
    puppet=data['actors']['enemies']['puppet']
    puppet['atlas']='void_puppet'
    puppet.pop('cell',None)


def upgrade_v9():
    used=set()
    data={}
    for name in ('world','actors','quests','weapons'):
        data[name]=rewrite(json.loads((DATA/(name+'.json')).read_text(encoding='utf-8')),used)
    data['world']['version']=9
    reorder_v9(data)
    theater_boss_v9(data)
    keeper_chase_v9(data)
    well_ending_v9(data)
    art_v9(data)
    for name,value in data.items():
        (DATA/(name+'.json')).write_text(json.dumps(value,ensure_ascii=False,indent=2),encoding='utf-8')
    unused=[k for k in STORY if k not in used]
    print('story 1.1 texts applied:',len(used),'/',len(STORY))
    for k in unused:
        print('  not found:',k.replace('\n','⏎'))


if __name__=='__main__':
    upgrade_v9()
