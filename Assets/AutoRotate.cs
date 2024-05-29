// AutoRotate.cs
// Created by Cui Lingzhi
// on 2024 - 05 - 24

using UnityEngine;

namespace ShaderExamples.CardEffect
{
    public class AutoRotate : MonoBehaviour
    {
        public float speed = 1;
        public float angle = 2;
        
        private float mSinV;
        private float mSum = 0;
        void Update()
        {
            mSum += speed * Time.deltaTime;
            mSinV = Mathf.Sin(mSum);

            transform.eulerAngles = new Vector3(0, angle * mSinV, 0);
        }
    }
}