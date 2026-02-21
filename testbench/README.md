"# test bench"

`define HARDWARE_TEST 1

이거 0으로 수정하면 Uart 검증 모드 되도록 설계

사용시 주의
1. top module 없이 짠 초안이라 time delay 계산이 어긋날 수 있음
2. 미완성 부분: 센서들 auto모드 부분, uart 입력신호간의 delay 계산