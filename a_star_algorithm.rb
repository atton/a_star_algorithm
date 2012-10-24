# -*- coding: utf-8 -*-
# A*アルゴリズムのちょっとした例

require 'CSV'

class AStarAlgorithm
  class Mass
    # マス用データクラス
    def initialize values
      @count      = values[:count]
      @operators  = values[:operators]
      @huristic   = values[:huristic]
      @distance   = values[:distance]
      @eval_value = @huristic + @distance
    end
    attr_reader :operators, :huristic, :distance, :eval_value
    attr_accessor :count
  end

  # 範囲。 Width x Width のマップを扱うとする
  Width = 10

  # オペレータ
  Operators = "↖↑↗→↘↓↙←"

  # 状態遷移関数
  Fai = {
    "↖" => [-1,-1],
    "↑" => [-1,0],
    "↗" => [-1,1],
    "→" => [0,1],
    "↘" => [1,1],
    "↓" => [1,0],
    "↙" => [1,-1],
    "←" => [0,-1]
  }
  # 状態遷移関数の逆関数。後戻り防止用に必要。
  InverseFai = {
    "↖" => "↘" ,
    "↑" => "↓" ,
    "↗" => "↙" ,
    "→" => "←" ,
    "↘" => "↖",
    "↓" => "↑",
    "↙" => "↗",
    "←" => "→"
  }

  # マップ。 
  # S = Q_i(開始位置), G = Q_f(終了位置)
  # . = 通常マス    .  X = 壁
  Map = [
    "XX........",
    "X.....G...",
    "..........",
    "...XXXXX..",
    ".......X..",
    "....S..X..",
    ".......X..",
    "XXX.......",
    "X.........",
    "......XX.."
  ]

  def huristic_function pos
    # ヒューリスティック関数。 h(n)に相当
    return Math::sqrt(((@goal[0]-pos[0])**2) + ((@goal[1]-pos[1])**2))
  end

  def distance_function pos
    # 出発点からの距離。 g(n)に相当
    if @fix_list.has_key?(pos)
      return @fix_list[pos][:distance]
    end
    if @unfix_list.has_key?(pos)
      return @unfix_list[pos][:distance]
    end
    puts "#{pos}はリストに存在していません"
    exit
  end

  def initialize
    @goal = get_position(Map,"G")
    # L2 のリスト
    @fix_list = {}
    # L1 のリスト
    @unfix_list = {
      get_position(Map,"S") => Mass.new({
      :operators => "",
      :count => "N",
      :distance => 0,
      :huristic  => huristic_function(get_position(Map,"S")),
    })
    }
  end

  def arround_eval pos,count
    # 戻る以外の移動可能場所の評価値を計算する
    mass = @unfix_list[pos] || @fix_list[pos]
    inverse_op = InverseFai[mass.operators[-1]] || ""
    Operators.sub(inverse_op,"").each_char do |op|
      # 移動可能なら
      if movable?(pos,op)
        # 評価したものをリストに追加
        insert_list(pos,op,count)
      end
    end
  end

  def move_once count
    # 最小のものを移動する
    min_index = @unfix_list.key(
      @unfix_list.values.min do |a,b|
      a.eval_value <=> b.eval_value
      end 
    )
    # ゴールか確認
    if min_index == @goal
      puts "探索に成功しました"
      puts "最短回数は #{@unfix_list[min_index].distance} で、移動方法は"
      puts "#{@unfix_list[min_index].operators}です"
      print_csv "result.csv"
      exit
    end

    # L1 から L2 へ移動
    @unfix_list[min_index].count = count
    @fix_list[min_index] = @unfix_list[min_index]
    @unfix_list.delete(min_index)
    arround_eval(min_index,count)
  end

  def run
    max_count = 10000
    1.upto(max_count) do |count|
      move_once count
      # show steps to csv
      # print_csv "step_#{count}.csv"
    end
    puts "#{max_count}回の探索では見つかりませんでした"
    exit
  end

  # support function
  private

  def get_position map,char
    # stub

    (0..(Width-1)).each do |col|
      char_pos = Map[col].index(char)
      if char_pos
        return [col,char_pos]
      end
    end
    puts "not fouund '#{char}' in map"
    exit
  end

  def movable? pos,op
    # pos から op へと移動可能かどうか
    return false unless (0..(Width-1)).include?(pos[0]+Fai[op][0])
    return false unless (0..(Width-1)).include?(pos[1]+Fai[op][1])
    op = Fai[op]
    # 壁か
    return false if(Map[pos[0]+op[0]][pos[1]+op[1]] == "X")
    return true
  end

  def insert_list pos,op,count
    # リストに追加する
    new_pos = move(pos,op)

    if @fix_list.has_key?(new_pos)
      # L2 に存在する場合
      update_fix_list pos,op,count
    elsif @unfix_list.has_key?(new_pos)
      # L1 に存在する場合
      update_unfix_list pos,op,count
    else
      # L1 にも L2 にも存在しない場合(i)
      new_mass = moved_mass(pos,op)
      @unfix_list[new_pos] = new_mass
    end
  end

  def update_fix_list pos,op,count
    # L2 に存在する場合の処理
    new_pos = move(pos,op)
    new_mass = moved_mass(pos,op)
    return if @fix_list[new_pos].nil?
    if @fix_list[new_pos].eval_value >= new_mass.eval_value
      # L2 の評価値より、今回の評価値が低い場合、L1へと移動する(iii)
      @unfix_list[new_pos] = new_mass
      @fix_list.delete(new_pos)
    end
  end

  def update_unfix_list pos,op,count
    # L1 に存在する場合の処理
    mass = @fix_list[pos]
    new_pos = move(pos,op)
    new_mass = moved_mass(pos,op)
    return if @unfix_list[new_pos].nil?
    if @unfix_list[new_pos].eval_value >= new_mass.eval_value
      # L1 よりも新しく移動する場合が評価値が低い場合は更新する
      @unfix_list[new_pos] = new_mass
    end
  end

  def move pos, op
    # オペレータを適用後の座標を返す
    new_pos = []
    new_pos[0] = Fai[op][0] + pos[0]
    new_pos[1] = Fai[op][1] + pos[1]
    new_pos
  end

  def moved_mass pos,op
    # オペレータを適用後のマス情報を返す
    new_pos = move(pos,op)
    mass = @fix_list[pos] 
    new_mass = Mass.new({
      :operators => mass.operators + op,
      :count => "",
      :distance =>  mass.distance + 1,
      :huristic  => huristic_function(new_pos)
    })
  end

  def print_csv file_name
    # file_name にcsv で全コマを出力する
    if File.exist?(file_name)
      File.delete(file_name)
    end

    CSV.open(file_name, "ab+") do |csv|
      (0..(Width-1)).each do |row_num| 
        row = get_csv_row(row_num)
        csv << row
      end
    end
  end

  def get_csv_row row_num
    # 指定行のcsv用データを返す
    (0..(Width-1)).map do |colunm_num|
      pos = [row_num,colunm_num]
      mass = @unfix_list[pos] || @fix_list[pos]

      str = "[#{pos[0]},#{pos[1]}] "
      str += Map[row_num][colunm_num] + "\n"

      if mass.nil?
        str += "none"
      else
        str += "c: " + mass.count.to_s
        str += "\n"
        str += "e: " + mass.eval_value.to_s
      end
    end
  end
end
AStarAlgorithm.new.run
