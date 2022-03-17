#! /bin/sh

# 不同的 value 大小
value_array=(1024 4096 16384 65536)
#value_array=(256)
# 测试总大小
test_all_size=81920000000   #8G

# db,wal 路径
bench_db_path="/mnt/ssd/test"
wal_dir="/mnt/ssd/test"
# bench 配置
bench_value="4096"
bench_compression="none" #"snappy,none"

# dbbench 负载集合
#bench_benchmarks="fillseq,stats,readseq,readrandom,stats" #"fillrandom,fillseq,readseq,readrandom,stats"
#bench_benchmarks="fillrandom,stats,readseq,readrandom,readrandom,readrandom,stats"
#bench_benchmarks="fillrandom,stats,wait,stats,readseq,readrandom,readrandom,readrandom,stats"
#bench_benchmarks="fillrandom,stats,wait,clean_cache,stats,readseq,readrandom,stats"
#bench_benchmarks="fillrandom,stats,sleep20s,clean_cache,stats,readseq,clean_cache,stats,readrandom,stats"
bench_benchmarks="fillrandom,stats,wait,clean_cache,stats,readseq,clean_cache,stats,readrandom,stats"
#bench_benchmarks="fillrandom,stats,wait,clean_cache,stats,readrandom,stats"
#bench_benchmarks="fillseq,stats"

# benchmark 操作数 2000w
bench_num="20000000"
# 读操作数 100w
bench_readnum="1000000"
#bench_max_open_files="1000"
# 后台线程 3
max_background_jobs="3"
# 8G
max_bytes_for_level_base="`expr 8 \* 1024 \* 1024 \* 1024`" 
#max_bytes_for_level_base="`expr 256 \* 1024 \* 1024`" 

threads="1"
# pmem 路径
pmem_path="/mnt/pmem0/nvm"
use_nvm="true"

# 记录写延迟
report_write_latency="false"

# dbbench 路径
bench_file_path="$(dirname $PWD )/db_bench"

bench_file_dir="$(dirname $PWD )"

if [ ! -f "${bench_file_path}" ];then
bench_file_path="$PWD/db_bench"
bench_file_dir="$PWD"
fi

if [ ! -f "${bench_file_path}" ];then
echo "Error:${bench_file_path} or $(dirname $PWD )/db_bench not find!"
exit 1
fi

# 运行单次测试
RUN_ONE_TEST() {
    const_params="
    --db=$bench_db_path \
    --wal_dir=$wal_dir \
    --threads=$threads \
    --value_size=$bench_value \
    --benchmarks=$bench_benchmarks \
    --num=$bench_num \
    --reads=$bench_readnum \
    --compression_type=$bench_compression \
    --max_background_jobs=$max_background_jobs \
    --max_bytes_for_level_base=$max_bytes_for_level_base \
    --report_write_latency=$report_write_latency \
    --use_nvm_module=$use_nvm \
    --pmem_path=$pmem_path \
    "
    cmd="$bench_file_path $const_params >>out.out 2>&1"
    echo $cmd >out.out
    echo $cmd
    eval $cmd
}

# 同步并清除页缓存
CLEAN_CACHE() {
    if [ -n "$bench_db_path" ];then
        rm -f $bench_db_path/*
    fi
    sleep 2
    sync
    echo 3 > /proc/sys/vm/drop_caches
    sleep 2
}

# 处理结果文件
COPY_OUT_FILE(){
    # 创建结果文件夹
    mkdir $bench_file_dir/result > /dev/null 2>&1
    # 创建不同的 value 大小对应的文件夹
    res_dir=$bench_file_dir/result/value-$bench_value
    mkdir $res_dir > /dev/null 2>&1
    # 拷贝对应的结果文件
    # compaction.csv, OP_DATA, OP_TIME.csv, out.out, Latency.csv, OPTIONS-*
    \cp -f $bench_file_dir/compaction.csv $res_dir/
    \cp -f $bench_file_dir/OP_DATA $res_dir/
    \cp -f $bench_file_dir/OP_TIME.csv $res_dir/
    \cp -f $bench_file_dir/out.out $res_dir/
    \cp -f $bench_file_dir/Latency.csv $res_dir/
    #\cp -f $bench_file_dir/NVM_LOG $res_dir/
    \cp -f $bench_db_path/OPTIONS-* $res_dir/
    #\cp -f $bench_db_path/LOG $res_dir/
}

# 跑全部测试
RUN_ALL_TEST() {
    # 使用不同的 value 大小进行测试
    for value in ${value_array[@]}; do
        # 每一次测试前清除页缓存
        CLEAN_CACHE
        # 数据的总大小不变，value 越大，数据越少
        bench_value="$value"
        bench_num="`expr $test_all_size / $bench_value`"

        # 运行单个测试
        RUN_ONE_TEST
        # 获取上一个命令的返回值
        # 如果不为 0 说明异常了，需要终止循环
        if [ $? -ne 0 ];then
            exit 1
        fi
        # 处理输出文件，并休息五秒
        COPY_OUT_FILE
        sleep 5
    done
}

RUN_ALL_TEST
